module Pod
  class Installer
    class Xcode
      # The {PodsProjectGenerator} handles generation of the 'Pods/Pods.xcodeproj'
      #
      class PodsProjectGenerator
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
            project.recreate_user_schemes(false)
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
              build_configuration.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = 'NO_SIGNING/' # a bogus provisioning profile ID assumed to be invalid
            end
          end
        end

        def install_file_references
          installer = FileReferencesInstaller.new(sandbox, pod_targets, project)
          installer.install!
        end

        def install_libraries
          UI.message '- Installing targets' do
            pod_targets.sort_by(&:name).each do |pod_target|
              target_installer = PodTargetInstaller.new(sandbox, pod_target)
              target_installer.install!
            end

            aggregate_targets.sort_by(&:name).each do |target|
              target_installer = AggregateTargetInstaller.new(sandbox, target)
              target_installer.install!
            end

            add_system_framework_dependencies
          end
        end

        def add_system_framework_dependencies
          # @TODO: Add Specs
          pod_targets.sort_by(&:name).each do |pod_target|
            pod_target.file_accessors.each do |file_accessor|
              file_accessor.spec_consumer.frameworks.each do |framework|
                if pod_target.should_build?
                  pod_target.native_target.add_system_framework(framework)
                end
              end
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
          aggregate_targets.each do |aggregate_target|
            is_app_extension = !(aggregate_target.user_targets.map(&:symbol_type) &
                                 [:app_extension, :watch_extension, :watch2_extension, :tv_extension, :messages_extension]).empty?
            is_app_extension ||= aggregate_target.user_targets.any? { |ut| ut.common_resolved_build_setting('APPLICATION_EXTENSION_API_ONLY') == 'YES' }

            aggregate_target.pod_targets.each do |pod_target|
              configure_app_extension_api_only_for_target(aggregate_target) if is_app_extension

              unless pod_target.should_build?
                pod_target.resource_bundle_targets.each do |resource_bundle_target|
                  aggregate_target.native_target.add_dependency(resource_bundle_target)
                end

                next
              end

              aggregate_target.native_target.add_dependency(pod_target.native_target)
              configure_app_extension_api_only_for_target(pod_target) if is_app_extension

              pod_target.dependent_targets.each do |pod_dependency_target|
                next unless pod_dependency_target.should_build?
                pod_target.native_target.add_dependency(pod_dependency_target.native_target)
                configure_app_extension_api_only_for_target(pod_dependency_target) if is_app_extension

                if pod_target.requires_frameworks?
                  product_ref = frameworks_group.files.find { |f| f.path == pod_dependency_target.product_name } ||
                    frameworks_group.new_product_ref_for_target(pod_dependency_target.product_basename, pod_dependency_target.product_type)
                  pod_target.native_target.frameworks_build_phase.add_file_reference(product_ref, true)
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
            sandbox.development_pods.keys.include?(pod_target.pod_name)
          end
        end

        #------------------------------------------------------------------------#

        # @! group Private Helpers

        private

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
