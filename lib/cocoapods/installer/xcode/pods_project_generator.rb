module Pod
  class Installer
    class Xcode
      # The {PodsProjectGenerator} handles generation of the 'Pods/Pods.xcodeproj'
      #
      class PodsProjectGenerator
        require 'cocoapods/installer/xcode/pods_project_generator/pod_target_integrator'
        require 'cocoapods/installer/xcode/pods_project_generator/target_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/pod_target_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/file_references_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/aggregate_target_installer'

        # @return [Pod::Project] the `Pods/Pods.xcodeproj` project.
        #
        attr_reader :project

        # @return [Array<AggregateTarget>] The model representations of an
        #         aggregation of pod targets generated for a target definition
        #         in the Podfile.
        #
        attr_reader :aggregate_targets

        # @return [Sandbox] The sandbox where the Pods should be installed.
        #
        attr_reader :sandbox

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
        # @param  [Array<AggregateTarget>] aggregate_targets     @see aggregate_targets
        # @param  [Sandbox]                sandbox               @see sandbox
        # @param  [Array<PodTarget>]       pod_targets           @see pod_targets
        # @param  [Analyzer]               analysis_result       @see analysis_result
        # @param  [InstallationOptions]    installation_options  @see installation_options
        # @param  [Config]                 config                @see config
        #
        def initialize(aggregate_targets, sandbox, pod_targets, analysis_result, installation_options, config)
          @aggregate_targets = aggregate_targets
          @sandbox = sandbox
          @pod_targets = pod_targets
          @analysis_result = analysis_result
          @installation_options = installation_options
          @config = config
        end

        def generate!
          prepare
          install_file_references
          install_libraries
          integrate_targets
          set_target_dependencies
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
            project.recreate_user_schemes(false) do |scheme, target|
              next unless library_product_types.include? target.symbol_type
              pod_target = pod_targets.find { |pt| pt.native_target == target }
              next if pod_target.nil? || pod_target.test_native_targets.empty?
              pod_target.test_native_targets.each { |test_native_target| scheme.add_test_target(test_native_target) }
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
              pod_target.supported_test_types.each do |test_type|
                Xcodeproj::XCScheme.share_scheme(project.path, pod_target.test_target_label(test_type))
              end
            end
          end
        end

        private

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
              build_configuration.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
              build_configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
            end
          end
        end

        def install_file_references
          installer = FileReferencesInstaller.new(sandbox, pod_targets, project)
          installer.install!
        end

        def install_libraries
          UI.message '- Installing targets' do
            umbrella_headers_by_dir = pod_targets.map do |pod_target|
              next unless pod_target.should_build? && pod_target.defines_module?
              pod_target.umbrella_header_path
            end.compact.group_by(&:dirname)

            pod_targets.sort_by(&:name).each do |pod_target|
              target_installer = PodTargetInstaller.new(sandbox, pod_target)
              target_installer.umbrella_headers_by_dir = umbrella_headers_by_dir
              target_installer.install!
            end

            aggregate_targets.sort_by(&:name).each do |target|
              target_installer = AggregateTargetInstaller.new(sandbox, target)
              target_installer.install!
            end

            add_system_framework_dependencies
          end
        end

        def integrate_targets
          pod_targets_to_integrate = pod_targets.select { |pt| !pt.test_native_targets.empty? || pt.contains_script_phases? }
          unless pod_targets_to_integrate.empty?
            UI.message '- Integrating targets' do
              pod_targets_to_integrate.each do |pod_target|
                PodTargetIntegrator.new(pod_target).integrate!
              end
            end
          end
        end

        def add_system_framework_dependencies
          # @TODO: Add Specs
          pod_targets.select(&:should_build?).sort_by(&:name).each do |pod_target|
            test_file_accessors, file_accessors = pod_target.file_accessors.partition { |fa| fa.spec.test_specification? }
            file_accessors.each do |file_accessor|
              add_system_frameworks_to_native_target(file_accessor, pod_target.native_target)
            end
            test_file_accessors.each do |test_file_accessor|
              native_target = pod_target.native_target_for_spec(test_file_accessor.spec)
              add_system_frameworks_to_native_target(test_file_accessor, native_target)
            end
          end
        end

        # Adds a target dependency for each pod spec to each aggregate target and
        # links the pod targets among each other.
        #
        # @return [void]
        #
        def set_target_dependencies
          frameworks_group = project.frameworks_group
          test_only_pod_targets = pod_targets.dup
          aggregate_targets.each do |aggregate_target|
            is_app_extension = !(aggregate_target.user_targets.map(&:symbol_type) &
                                 [:app_extension, :watch_extension, :watch2_extension, :tv_extension, :messages_extension]).empty?
            is_app_extension ||= aggregate_target.user_targets.any? { |ut| ut.common_resolved_build_setting('APPLICATION_EXTENSION_API_ONLY') == 'YES' }

            aggregate_target.search_paths_aggregate_targets.each do |search_paths_target|
              aggregate_target.native_target.add_dependency(search_paths_target.native_target)
            end

            aggregate_target.pod_targets.each do |pod_target|
              test_only_pod_targets.delete(pod_target)
              configure_app_extension_api_only_for_target(aggregate_target) if is_app_extension

              unless pod_target.should_build?
                add_resource_bundles_to_native_target(pod_target, aggregate_target.native_target)
                add_pod_target_test_dependencies(pod_target, frameworks_group)
                next
              end

              aggregate_target.native_target.add_dependency(pod_target.native_target)
              configure_app_extension_api_only_for_target(pod_target) if is_app_extension

              add_dependent_targets_to_native_target(pod_target.dependent_targets,
                                                     pod_target.native_target, is_app_extension,
                                                     pod_target.requires_frameworks? && !pod_target.static_framework?,
                                                     frameworks_group)
              unless pod_target.static_framework?
                add_pod_target_test_dependencies(pod_target, frameworks_group)
              end
            end
          end
          # Wire up remaining pod targets used only by tests and are not used by any aggregate target.
          test_only_pod_targets.each do |pod_target|
            unless pod_target.should_build?
              add_pod_target_test_dependencies(pod_target, frameworks_group)
              next
            end
            unless pod_target.static_framework?
              add_dependent_targets_to_native_target(pod_target.dependent_targets,
                                                     pod_target.native_target, false,
                                                     pod_target.requires_frameworks?, frameworks_group)
              add_pod_target_test_dependencies(pod_target, frameworks_group)
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

        private

        def add_pod_target_test_dependencies(pod_target, frameworks_group)
          test_dependent_targets = pod_target.all_dependent_targets
          pod_target.test_specs_by_native_target.each do |test_native_target, test_specs|
            test_dependent_targets.reject(&:should_build?).each do |test_dependent_target|
              add_resource_bundles_to_native_target(test_dependent_target, test_native_target)
            end
            add_dependent_targets_to_native_target(test_dependent_targets, test_native_target, false, pod_target.requires_frameworks?, frameworks_group)
            test_spec_consumers = test_specs.map { |test_spec| test_spec.consumer(pod_target.platform) }
            if test_spec_consumers.any?(&:requires_app_host?)
              app_host_target = project.targets.find { |t| t.name == pod_target.app_host_label(test_specs.first.test_type) }
              test_native_target.add_dependency(app_host_target)
            end
          end
        end

        def add_dependent_targets_to_native_target(dependent_targets, native_target, is_app_extension, requires_frameworks, frameworks_group)
          dependent_targets.each do |pod_dependency_target|
            next unless pod_dependency_target.should_build?
            native_target.add_dependency(pod_dependency_target.native_target)
            configure_app_extension_api_only_for_target(pod_dependency_target) if is_app_extension

            if requires_frameworks
              product_ref = frameworks_group.files.find { |f| f.path == pod_dependency_target.product_name } ||
                  frameworks_group.new_product_ref_for_target(pod_dependency_target.product_basename, pod_dependency_target.product_type)
              native_target.frameworks_build_phase.add_file_reference(product_ref, true)
            end
          end
        end

        def add_system_frameworks_to_native_target(file_accessor, native_target)
          file_accessor.spec_consumer.frameworks.each do |framework|
            native_target.add_system_framework(framework)
          end
        end

        def add_resource_bundles_to_native_target(dependent_target, native_target)
          resource_bundle_targets = dependent_target.resource_bundle_targets + dependent_target.test_resource_bundle_targets
          resource_bundle_targets.each do |resource_bundle_target|
            native_target.add_dependency(resource_bundle_target)
          end
        end

        # Sets the APPLICATION_EXTENSION_API_ONLY build setting to YES for all
        # configurations of the given target
        #
        def configure_app_extension_api_only_for_target(target)
          target.native_target.build_configurations.each do |config|
            config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
          end
        end
      end
    end
  end
end
