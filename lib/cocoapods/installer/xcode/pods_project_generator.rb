module Pod
  class Installer
    class Xcode
      # The {PodsProjectGenerator} handles generation of CocoaPods Xcode projects.
      #
      class PodsProjectGenerator
        require 'cocoapods/installer/xcode/pods_project_generator/target_installer_helper'
        require 'cocoapods/installer/xcode/pods_project_generator/pod_target_integrator'
        require 'cocoapods/installer/xcode/pods_project_generator/target_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/target_installation_result'
        require 'cocoapods/installer/xcode/pods_project_generator/pod_target_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/file_references_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/aggregate_target_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/project_generator'
        require 'cocoapods/installer/xcode/pods_project_generator_result'

        # @return [Sandbox] The sandbox where the Pods should be installed.
        #
        attr_reader :sandbox

        # @return [Array<AggregateTarget>] The model representations of an
        #         aggregation of pod targets generated for a target definition
        #         in the Podfile.
        #
        attr_reader :aggregate_targets

        # @return [Array<PodTarget>] The model representations of pod targets.
        #
        attr_reader :pod_targets

        # @return [Analyzer] the analyzer which provides the information about what
        #         needs to be installed.
        #
        attr_reader :analysis_result

        # @return [InstallationOptions] the installation options from the Podfile.
        #
        attr_reader :installation_options

        # @return [Config] the global CocoaPods configuration.
        #
        attr_reader :config

        # Initialize a new instance
        #
        # @param  [Sandbox]                sandbox               @see #sandbox
        # @param  [Array<AggregateTarget>] aggregate_targets     @see #aggregate_targets
        # @param  [Array<PodTarget>]       pod_targets           @see #pod_targets
        # @param  [Analyzer]               analysis_result       @see #analysis_result
        # @param  [InstallationOptions]    installation_options  @see #installation_options
        # @param  [Config]                 config                @see #config
        #
        def initialize(sandbox, aggregate_targets, pod_targets, analysis_result, installation_options, config)
          @sandbox = sandbox
          @aggregate_targets = aggregate_targets
          @pod_targets = pod_targets
          @analysis_result = analysis_result
          @installation_options = installation_options
          @config = config
        end

        # Shares schemes of development Pods.
        #
        # @return [void]
        #
        def share_development_pod_schemes(project, development_pod_targets = [])
          targets = development_pod_targets.select do |target|
            target.should_build? && share_scheme_for_development_pod?(target.pod_name)
          end
          targets.each do |pod_target|
            configure_schemes_for_pod_target(project, pod_target)
          end
        end

        # @!attribute [Hash{String => TargetInstallationResult}] pod_target_installation_results
        # @!attribute [Hash{String => TargetInstallationResult}] aggregate_target_installation_results
        InstallationResults = Struct.new(:pod_target_installation_results, :aggregate_target_installation_results)

        private

        def install_file_references(project, pod_targets)
          UI.message "- Installing files into #{project.project_name} project" do
            installer = FileReferencesInstaller.new(sandbox, pod_targets, project, installation_options.preserve_pod_file_structure)
            installer.install!
          end
        end

        def install_pod_targets(project, pod_targets)
          umbrella_headers_by_dir = pod_targets.map do |pod_target|
            next unless pod_target.should_build? && pod_target.defines_module?
            pod_target.umbrella_header_path
          end.compact.group_by(&:dirname)

          pod_target_installation_results = Hash[pod_targets.sort_by(&:name).map do |pod_target|
            umbrella_headers_in_header_dir = umbrella_headers_by_dir[pod_target.module_map_path.dirname]
            target_installer = PodTargetInstaller.new(sandbox, project, pod_target, umbrella_headers_in_header_dir)
            [pod_target.name, target_installer.install!]
          end]

          # Hook up system framework dependencies for the pod targets that were just installed.
          pod_target_installation_result_values = pod_target_installation_results.values.compact
          unless pod_target_installation_result_values.empty?
            add_system_framework_dependencies(pod_target_installation_result_values)
          end

          pod_target_installation_results
        end

        def install_aggregate_targets(project, aggregate_targets)
          UI.message '- Installing Aggregate Targets' do
            aggregate_target_installation_results = Hash[aggregate_targets.sort_by(&:name).map do |target|
              target_installer = AggregateTargetInstaller.new(sandbox, project, target)
              [target.name, target_installer.install!]
            end]

            aggregate_target_installation_results
          end
        end

        # @param [Hash{String => InstallationResult}] pod_target_installation_results
        #        the installations to integrate
        #
        # @return [void]
        #
        def integrate_targets(pod_target_installation_results)
          pod_installations_to_integrate = pod_target_installation_results.values.select do |pod_target_installation_result|
            pod_target = pod_target_installation_result.target
            !pod_target_installation_result.test_native_targets.empty? ||
                !pod_target_installation_result.app_native_targets.empty? ||
                pod_target.contains_script_phases?
          end
          return if pod_installations_to_integrate.empty?

          UI.message '- Integrating targets' do
            use_input_output_paths = !installation_options.disable_input_output_paths
            pod_installations_to_integrate.each do |pod_target_installation_result|
              PodTargetIntegrator.new(pod_target_installation_result, :use_input_output_paths => use_input_output_paths).integrate!
            end
          end
        end

        def add_system_framework_dependencies(pod_target_installation_results)
          sorted_installation_results = pod_target_installation_results.sort_by do |pod_target_installation_result|
            pod_target_installation_result.target.name
          end
          sorted_installation_results.each do |target_installation_result|
            pod_target = target_installation_result.target
            next unless pod_target.should_build?
            next if pod_target.build_as_static?
            pod_target.file_accessors.each do |file_accessor|
              native_target = target_installation_result.native_target_for_spec(file_accessor.spec)
              add_system_frameworks_to_native_target(native_target, file_accessor)
            end
          end
        end

        # Adds a target dependency for each pod spec to each aggregate target and
        # links the pod targets among each other.
        #
        # @param  [Array[Hash{String=>TargetInstallationResult}]] target_installation_results
        #         the installation results that were produced when all targets were installed. This includes
        #         pod target installation results and aggregate target installation results.
        #
        # @return [void]
        #
        def wire_target_dependencies(target_installation_results)
          pod_target_installation_results_hash = target_installation_results.pod_target_installation_results
          aggregate_target_installation_results_hash = target_installation_results.aggregate_target_installation_results

          # Wire up aggregate targets
          aggregate_target_installation_results_hash.values.each do |aggregate_target_installation_result|
            aggregate_target = aggregate_target_installation_result.target
            aggregate_native_target = aggregate_target_installation_result.native_target
            is_app_extension = !(aggregate_target.user_targets.map(&:symbol_type) &
                [:app_extension, :watch_extension, :watch2_extension, :tv_extension, :messages_extension]).empty?
            is_app_extension ||= aggregate_target.user_targets.any? { |ut| ut.common_resolved_build_setting('APPLICATION_EXTENSION_API_ONLY') == 'YES' }
            configure_app_extension_api_only_to_native_target(aggregate_native_target) if is_app_extension
            # Wire up dependencies that are part of inherit search paths for this aggregate target.
            aggregate_target.search_paths_aggregate_targets.each do |search_paths_target|
              aggregate_native_target.add_dependency(aggregate_target_installation_results_hash[search_paths_target.name].native_target)
            end
            # Wire up all pod target dependencies to aggregate target.
            aggregate_target.pod_targets.each do |pod_target|
              pod_target_native_target = pod_target_installation_results_hash[pod_target.name].native_target
              aggregate_native_target.add_dependency(pod_target_native_target)
              configure_app_extension_api_only_to_native_target(pod_target_native_target) if is_app_extension
            end
          end

          # Wire up pod targets
          pod_target_installation_results_hash.values.each do |pod_target_installation_result|
            pod_target = pod_target_installation_result.target
            native_target = pod_target_installation_result.native_target
            project = native_target.project
            frameworks_group = project.frameworks_group
            # First, wire up all resource bundles.
            pod_target_installation_result.resource_bundle_targets.each do |resource_bundle_target|
              native_target.add_dependency(resource_bundle_target)
              if pod_target.build_as_dynamic_framework? && pod_target.should_build?
                native_target.add_resources([resource_bundle_target.product_reference])
              end
            end
            # Wire up all dependencies to this pod target, if any.
            dependent_targets = pod_target.dependent_targets
            dependent_targets.each do |dependent_target|
              dependent_project = pod_target_installation_results_hash[dependent_target.name].native_target.project
              if dependent_project != project
                project.add_subproject_reference(dependent_project, project.dependencies_group)
              end
              native_target.add_dependency(pod_target_installation_results_hash[dependent_target.name].native_target)
              add_framework_file_reference_to_native_target(native_target, pod_target, dependent_target, frameworks_group)
            end
            # Wire up test native targets.
            unless pod_target_installation_result.test_native_targets.empty?
              pod_target_installation_result.test_specs_by_native_target.each do |test_native_target, test_spec|
                resource_bundle_native_targets = pod_target_installation_result.test_resource_bundle_targets[test_spec.name]
                unless resource_bundle_native_targets.nil?
                  resource_bundle_native_targets.each do |test_resource_bundle_target|
                    test_native_target.add_dependency(test_resource_bundle_target)
                  end
                end
                test_dependent_targets = pod_target.test_dependent_targets_by_spec_name.fetch(test_spec.name, []).unshift(pod_target).uniq
                test_dependent_targets.each do |test_dependent_target|
                  dependency_installation_result = pod_target_installation_results_hash[test_dependent_target.name]
                  dependent_test_project = pod_target_installation_results_hash[test_dependent_target.name].native_target.project
                  if dependent_test_project != project
                    project.add_subproject_reference(dependent_test_project, project.dependencies_group)
                  end
                  test_native_target.add_dependency(dependency_installation_result.native_target)
                  add_framework_file_reference_to_native_target(test_native_target, pod_target, test_dependent_target, frameworks_group)
                end
              end
            end

            # Wire up app native targets.
            unless pod_target_installation_result.app_native_targets.empty?
              pod_target_installation_result.app_specs_by_native_target.each do |app_native_target, app_spec|
                resource_bundle_native_targets = pod_target_installation_result.app_resource_bundle_targets[app_spec.name]
                unless resource_bundle_native_targets.nil?
                  resource_bundle_native_targets.each do |app_resource_bundle_target|
                    app_native_target.add_dependency(app_resource_bundle_target)
                  end
                end
                app_dependent_targets = pod_target.app_dependent_targets_by_spec_name.fetch(app_spec.name, []).unshift(pod_target).uniq
                app_dependent_targets.each do |app_dependent_target|
                  dependency_installation_result = pod_target_installation_results_hash[app_dependent_target.name]
                  dependency_project = dependency_installation_result.native_target.project
                  if dependency_project != project
                    project.add_subproject_reference(dependency_project, project.dependencies_group)
                  end
                  app_native_target.add_dependency(dependency_installation_result.native_target)
                  add_framework_file_reference_to_native_target(app_native_target, pod_target, app_dependent_target, frameworks_group)
                end
              end
            end
          end
        end

        # @param  [String] pod The root name of the development pod.
        #
        # @return [Bool] whether the scheme for the given development pod should be
        #         shared.
        #
        def share_scheme_for_development_pod?(pod)
          case dev_pods_to_share = installation_options.share_schemes_for_development_pods
          when TrueClass, FalseClass, NilClass
            dev_pods_to_share
          when Array
            dev_pods_to_share.any? { |dev_pod| dev_pod === pod } # rubocop:disable Style/CaseEquality
          else
            raise Informative, 'Unable to handle share_schemes_for_development_pods ' \
              "being set to #{dev_pods_to_share.inspect} -- please set it to true, " \
              'false, or an array of pods to share schemes for.'
          end
        end

        #------------------------------------------------------------------------#

        # @! group Private Helpers

        def add_system_frameworks_to_native_target(native_target, file_accessor)
          file_accessor.spec_consumer.frameworks.each do |framework|
            native_target.add_system_framework(framework)
          end
        end

        def add_framework_file_reference_to_native_target(native_target, pod_target, dependent_target, frameworks_group)
          if pod_target.should_build? && pod_target.build_as_dynamic? && dependent_target.should_build?
            product_ref = frameworks_group.files.find { |f| f.path == dependent_target.product_name } ||
                frameworks_group.new_product_ref_for_target(dependent_target.product_basename, dependent_target.product_type)
            native_target.frameworks_build_phase.add_file_reference(product_ref, true)
          end
        end

        def configure_app_extension_api_only_to_native_target(native_target)
          native_target.build_configurations.each do |config|
            config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
          end
        end

        def configure_schemes_for_pod_target(project, pod_target)
          specs = [pod_target.root_spec] + pod_target.test_specs + pod_target.app_specs
          specs.each do |spec|
            scheme_name = spec.spec_type == :library ? pod_target.label : pod_target.non_library_spec_label(spec)
            scheme_configuration = pod_target.scheme_for_spec(spec)
            unless scheme_configuration.empty?
              scheme_path = Xcodeproj::XCScheme.user_data_dir(project.path) + "#{scheme_name}.xcscheme"
              scheme = Xcodeproj::XCScheme.new(scheme_path)
              command_line_arguments = scheme.launch_action.command_line_arguments
              scheme_configuration.fetch(:launch_arguments, []).each do |launch_arg|
                command_line_arguments.assign_argument(:argument => launch_arg, :enabled => true)
              end
              scheme.launch_action.command_line_arguments = command_line_arguments
              environment_variables = scheme.launch_action.environment_variables
              scheme_configuration.fetch(:environment_variables, {}).each do |k, v|
                environment_variables.assign_variable(:key => k, :value => v)
              end
              scheme.launch_action.environment_variables = environment_variables
              scheme.save!
            end
            Xcodeproj::XCScheme.share_scheme(project.path, scheme_name)
          end
        end
      end
    end
  end
end
