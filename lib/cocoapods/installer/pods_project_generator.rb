module Pod
  class Installer


    # Generates the Pods project according to the targets identified by the
    # analyzer.
    #
    class PodsProjectGenerator

      autoload :FileReferencesInstaller,  'cocoapods/installer/pods_project_generator/file_references_installer'
      autoload :TargetInstaller,          'cocoapods/installer/pods_project_generator/target_installer'
      autoload :AggregateTargetInstaller, 'cocoapods/installer/pods_project_generator/target_installer/aggregate_target_installer'
      autoload :PodTargetInstaller,       'cocoapods/installer/pods_project_generator/target_installer/pod_target_installer'

      # @return [Sandbox] The sandbox of the installation.
      #
      attr_reader :sandbox

      # @return [Array<AggregateTarget>] The aggregate targets of the
      #         installation.
      #
      attr_reader :aggregate_targets

      # @param  [Sandbox] sandbox @see sandbox
      # @param  [Array<AggregateTarget>] aggregate_targets @see aggregate_targets
      #
      def initialize(sandbox, aggregate_targets)
        @sandbox = sandbox
        @aggregate_targets = aggregate_targets
        @user_build_configurations = []
      end

      # @return [Pathname] The path of the Podfile.
      #
      attr_accessor :podfile_path

      # @return [Hash] The name and the type of the build configurations of the
      #         user.
      #
      attr_accessor :user_build_configurations

      # Generates the Pods project.
      #
      # @return [void]
      #
      def install
        prepare_project
        install_file_references
        install_targets
        install_system_frameworks
        set_target_dependencies
        link_aggregate_target
      end

      # @return [Project] the generated Pods project.
      #
      attr_reader :project

      # Writes the Pods project to the disk.
      #
      # @return [void]
      #
      def write_pod_project
        UI.message "- Writing Xcode project file to #{UI.path sandbox.project_path}" do
          clean_up_project
          project.save
        end
      end


      private

      # @!group Installation steps
      #-----------------------------------------------------------------------#

      # Creates the Pods project from scratch.
      #
      # @return [void]
      #
      def prepare_project
        UI.message "- Creating Pods project" do
          @project = Pod::Project.new(sandbox.project_path)

          user_build_configurations.each do |name, type|
            project.add_build_configuration(name, type)
          end

          pod_names = pod_targets.map(&:pod_name).uniq
          pod_names.each do |pod_name|
            path = sandbox.pod_dir(pod_name)
            local = sandbox.local?(pod_name)
            project.add_pod_group(pod_name, path, local)
          end

          if podfile_path
            project.add_podfile(podfile_path)
          end

          sandbox.project = @project
          platforms = aggregate_targets.map(&:platform)
          osx_deployment_target = platforms.select { |p| p.name == :osx }.map(&:deployment_target).min
          ios_deployment_target = platforms.select { |p| p.name == :ios }.map(&:deployment_target).min
          project.build_configurations.each do |build_configuration|
            build_configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = osx_deployment_target.to_s if osx_deployment_target
            build_configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = ios_deployment_target.to_s if ios_deployment_target
            build_configuration.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
          end
        end
      end

      # Installs the file references in the Pods project. This is done once per
      # Pod as the same file reference might be shared by multiple aggregate
      # targets.
      #
      # @return [void]
      #
      def install_file_references
        installer = FileReferencesInstaller.new(sandbox, pod_targets, project)
        installer.install!
      end

      # Installs the pods and the aggregate targets generating their support
      # files.
      #
      # @return [void]
      #
      def install_targets
        UI.message"- Installing Targets" do
          pod_targets.sort_by(&:name).each do |pod_target|
            next if pod_target.target_definition.empty?
            target_installer = PodTargetInstaller.new(sandbox, pod_target)
            target_installer.install!
          end

          aggregate_targets.sort_by(&:name).each do |target|
            next if target.target_definition.empty?
            target_installer = AggregateTargetInstaller.new(sandbox, target)
            target_installer.install!
          end
        end
      end

      # Generates file references to the system frameworks used by the targets.
      # This is done for informative purposes and is not needed as the
      # canonical source for the build settings are the xcconfig files.
      #
      # @return [void]
      #
      def install_system_frameworks
        pod_targets.each do |pod_target|
          pod_target.specs.each do |spec|
            spec.consumer(pod_target.platform).frameworks.each do |framework|
              project.add_system_framework(framework, pod_target.target)
            end
          end
        end
      end

      # Sets the dependencies of the targets.
      #
      # @return [void]
      #
      def set_target_dependencies
        aggregate_targets.each do |aggregate_target|
          aggregate_target.pod_targets.each do |pod_target|
            aggregate_target.target.add_dependency(pod_target.target)
            pod_target.dependencies.each do |dep|
              pod_dependency_target = aggregate_target.pod_targets.find { |target| target.pod_name == dep }
              pod_target.target.add_dependency(pod_dependency_target.target)
            end
          end
        end
      end

      # Links the aggregate targets with all the dependent pod targets.
      #
      # @return [void]
      #
      def link_aggregate_target
        aggregate_targets.each do |aggregate_target|
          native_target = aggregate_target.target
          aggregate_target.pod_targets.each do |pod_target|
            product = pod_target.target.product_reference
            native_target.frameworks_build_phase.add_file_reference(product)
          end
        end
      end


      private

      # @!group Write steps
      #-----------------------------------------------------------------------#

      # Cleans up the project to prepare it for serialization.
      #
      # @return [void]
      #
      def clean_up_project
        project.pods.remove_from_project if project.pods.empty?
        project.development_pods.remove_from_project if project.development_pods.empty?
        project.main_group.recursively_sort_by_type
      end


      private

      # @!group Private Helpers
      #-----------------------------------------------------------------------#

      # @return [Array<PodTarget>] The pod targets generated by the installation
      #         process.
      #
      def pod_targets
        aggregate_targets.map(&:pod_targets).flatten
      end

      #-----------------------------------------------------------------------#

    end
  end
end
