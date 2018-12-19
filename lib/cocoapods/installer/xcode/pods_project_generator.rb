module Pod
  class Installer
    class Xcode
      # The {PodsProjectGenerator} handles generation of the 'Pods/Pods.xcodeproj'
      #
      class PodsProjectGenerator
        require 'cocoapods/installer/xcode/pods_project_generator/target_installer_helper'
        require 'cocoapods/installer/xcode/pods_project_generator/pod_target_integrator'
        require 'cocoapods/installer/xcode/pods_project_generator/target_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/target_installation_result'
        require 'cocoapods/installer/xcode/pods_project_generator/pod_target_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/file_references_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/aggregate_target_installer'

        # @return [Sandbox] The sandbox where the Pods should be installed.
        #
        attr_reader :sandbox

        # @return [Pod::Project] the `Pods/Pods.xcodeproj` project.
        #
        attr_reader :project

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

        def generate!
          prepare
          install_file_references
          @target_installation_results = install_targets
          integrate_targets(@target_installation_results.pod_target_installation_results)
          wire_target_dependencies(@target_installation_results)
          @target_installation_results
        end

        def write
          UI.message "- Writing Xcode project file to #{UI.path sandbox.project_path}" do
            project.pods.remove_from_project if project.pods.empty?
            project.development_pods.remove_from_project if project.development_pods.empty?
            project.sort(:groups_position => :below)
            if installation_options.deterministic_uuids?
              UI.message('- Generating deterministic UUIDs') { project.predictabilize_uuids }
            end
            library_product_types = [:framework, :dynamic_library, :static_library]

            pod_target_installation_results = @target_installation_results.pod_target_installation_results
            results_by_native_target = Hash[pod_target_installation_results.map do |_, result|
              [result.native_target, result]
            end]
            project.recreate_user_schemes(false) do |scheme, target|
              next unless target.respond_to?(:symbol_type)
              next unless library_product_types.include? target.symbol_type
              installation_result = results_by_native_target[target]
              next unless installation_result
              installation_result.test_native_targets.each do |test_native_target|
                scheme.add_test_target(test_native_target)
              end
            end
            project.save
          end
        end

        # Shares schemes of development Pods.
        #
        # @return [void]
        #
        def share_development_pod_schemes
          development_pod_targets.select(&:should_build?).each do |pod_target|
            next unless share_scheme_for_development_pod?(pod_target.pod_name)
            Xcodeproj::XCScheme.share_scheme(project.path, pod_target.label)
            if pod_target.contains_test_specifications?
              pod_target.test_specs.each do |test_spec|
                Xcodeproj::XCScheme.share_scheme(project.path, pod_target.test_target_label(test_spec))
              end
            end
          end
        end

        private

        InstallationResults = Struct.new(:pod_target_installation_results, :aggregate_target_installation_results)

        def create_project
          if object_version = aggregate_targets.map(&:user_project).compact.map { |p| p.object_version.to_i }.min
            Pod::Project.new(sandbox.project_path, false, object_version)
          else
            Pod::Project.new(sandbox.project_path)
          end
        end

        # Creates the Pods project from scratch if it doesn't exists.
        #
        # @return [void]
        #
        # @todo   Clean and modify the project if it exists.
        #
        def prepare
          UI.message '- Creating Pods project' do
            @project = create_project
            analysis_result.all_user_build_configurations.each do |name, type|
              @project.add_build_configuration(name, type)
            end
            # Reset symroot just in case the user has added a new build configuration other than 'Debug' or 'Release'.
            @project.symroot = Pod::Project::LEGACY_BUILD_ROOT

            pod_names = pod_targets.map(&:pod_name).uniq
            pod_names.each do |pod_name|
              local = sandbox.local?(pod_name)
              path = sandbox.pod_dir(pod_name)
              was_absolute = sandbox.local_path_was_absolute?(pod_name)
              @project.add_pod_group(pod_name, path, local, was_absolute)
            end

            if config.podfile_path
              @project.add_podfile(config.podfile_path)
            end

            sandbox.project = @project
            platforms = aggregate_targets.map(&:platform)
            osx_deployment_target = platforms.select { |p| p.name == :osx }.map(&:deployment_target).min
            ios_deployment_target = platforms.select { |p| p.name == :ios }.map(&:deployment_target).min
            watchos_deployment_target = platforms.select { |p| p.name == :watchos }.map(&:deployment_target).min
            tvos_deployment_target = platforms.select { |p| p.name == :tvos }.map(&:deployment_target).min
            @project.build_configurations.each do |build_configuration|
              build_configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = osx_deployment_target.to_s if osx_deployment_target
              build_configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = ios_deployment_target.to_s if ios_deployment_target
              build_configuration.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = watchos_deployment_target.to_s if watchos_deployment_target
              build_configuration.build_settings['TVOS_DEPLOYMENT_TARGET'] = tvos_deployment_target.to_s if tvos_deployment_target
              build_configuration.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
              build_configuration.build_settings['CLANG_ENABLE_OBJC_ARC'] = 'YES'
            end
          end
        end

        def install_file_references
          installer = FileReferencesInstaller.new(sandbox, pod_targets, project, installation_options.preserve_pod_file_structure)
          installer.install!
        end

        def install_targets
          UI.message '- Installing targets' do
            umbrella_headers_by_dir = pod_targets.map do |pod_target|
              next unless pod_target.should_build? && pod_target.defines_module?
              pod_target.umbrella_header_path
            end.compact.group_by(&:dirname)

            pod_target_installation_results = Hash[pod_targets.sort_by(&:name).map do |pod_target|
              umbrella_headers_in_header_dir = umbrella_headers_by_dir[pod_target.module_map_path.dirname]
              target_installer = PodTargetInstaller.new(sandbox, @project, pod_target, umbrella_headers_in_header_dir)
              [pod_target.name, target_installer.install!]
            end]

            # Hook up system framework dependencies for the pod targets that were just installed.
            pod_target_installation_result_values = pod_target_installation_results.values.compact
            unless pod_target_installation_result_values.empty?
              add_system_framework_dependencies(pod_target_installation_result_values)
            end

            aggregate_target_installation_results = Hash[aggregate_targets.sort_by(&:name).map do |target|
              target_installer = AggregateTargetInstaller.new(sandbox, @project, target)
              [target.name, target_installer.install!]
            end]

            InstallationResults.new(pod_target_installation_results, aggregate_target_installation_results)
          end
        end

        def integrate_targets(pod_target_installation_results)
          pod_installations_to_integrate = pod_target_installation_results.values.select do |pod_target_installation_result|
            pod_target = pod_target_installation_result.target
            !pod_target_installation_result.test_native_targets.empty? || pod_target.contains_script_phases?
          end
          unless pod_installations_to_integrate.empty?
            UI.message '- Integrating targets' do
              pod_installations_to_integrate.each do |pod_target_installation_result|
                PodTargetIntegrator.new(pod_target_installation_result, installation_options).integrate!
              end
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
            next if !pod_target.requires_frameworks? || pod_target.static_framework?
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
          frameworks_group = project.frameworks_group
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
            # First, wire up all resource bundles.
            pod_target_installation_result.resource_bundle_targets.each do |resource_bundle_target|
              native_target.add_dependency(resource_bundle_target)
              if pod_target.requires_frameworks? && pod_target.should_build?
                native_target.add_resources([resource_bundle_target.product_reference])
              end
            end
            # Wire up all dependencies to this pod target, if any.
            dependent_targets = pod_target.dependent_targets
            dependent_targets.each do |dependent_target|
              native_target.add_dependency(pod_target_installation_results_hash[dependent_target.name].native_target)
              add_framework_file_reference_to_native_target(native_target, pod_target, dependent_target, frameworks_group)
            end
            # Wire up test native targets.
            unless pod_target_installation_result.test_native_targets.empty?
              pod_target_installation_result.test_specs_by_native_target.each do |test_native_target, test_specs|
                test_dependent_targets = test_specs.flat_map { |s| pod_target.test_dependent_targets_by_spec_name[s.name] }.compact.unshift(pod_target).uniq
                test_dependent_targets.each do |test_dependent_target|
                  dependency_installation_result = pod_target_installation_results_hash[test_dependent_target.name]
                  resource_bundle_native_targets = dependency_installation_result.test_resource_bundle_targets[test_specs.first.name]
                  unless resource_bundle_native_targets.nil?
                    resource_bundle_native_targets.each do |test_resource_bundle_target|
                      test_native_target.add_dependency(test_resource_bundle_target)
                    end
                  end
                  test_native_target.add_dependency(dependency_installation_result.native_target)
                  add_framework_file_reference_to_native_target(test_native_target, pod_target, test_dependent_target, frameworks_group)
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

        # @return [Array<Library>] The targets of the development pods generated by
        #         the installation process.
        #
        def development_pod_targets
          pod_targets.select do |pod_target|
            sandbox.local?(pod_target.pod_name)
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
          if pod_target.should_build? && pod_target.requires_frameworks? && !pod_target.static_framework? && dependent_target.should_build?
            product_ref = frameworks_group.files.find { |f| f.path == dependent_target.product_name } ||
                frameworks_group.new_product_ref_for_target(dependent_target.product_basename, dependent_target.product_type)
            native_target.frameworks_build_phase.add_file_reference(product_ref, true)
          end
        end

        # Sets the APPLICATION_EXTENSION_API_ONLY build setting to YES for all
        # configurations of the given native target.
        #
        def configure_app_extension_api_only_to_native_target(native_target)
          native_target.build_configurations.each do |config|
            config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
          end
        end
      end
    end
  end
end
