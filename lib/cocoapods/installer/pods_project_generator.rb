module Pod
  class Installer

    # Generates the Pods project according to the targets identified by the
    # analyzer.
    #
    # # Incremental editing
    #
    # The generator will edit exiting projects instead of recreating them from
    # scratch. This behaviour significantly complicates the logic but leads to
    # dramatic performance benefits for the installation times. Another feature
    # of the incremental editing is the preservation of the UUIDs in the
    # project which allows to easily compare projects, reduce SCM noise (if the
    # CocoaPods artifacts are kept under source control), and finally, to
    # improve indexing and build time in Xcode.
    #
    # ## Assumptions
    #
    # To tame the complexity of the incremental editing, the generator relies
    # on the following assumptions:
    #
    # - Unrecognized targets and groups are removed early so the rest of the
    #   generation can focus on adding references if missing. In this way the
    #   same code path can be shared with the generation from scratch.
    # - The file references of the Pods are all stored in a dedicated group.
    # - The support files for a Pod are stored in a group which in turn is
    #   namespaced per aggregate target.
    # - The support files of an aggregate target are stored in its group.
    # - The support files generator is incremental and doesn't duplicates file
    #   references.
    #
    # ## Logic overview
    #
    # 1. The pods project is prepared.
    #    - The Pods project is generated from scratch if needed.
    #    - Otherwise the project is recreated from scratch and cleaned.
    #      - Existing native targets are matched to the targets.
    #      - Unrecognized targets are removed with any reference to them in the
    #        build phases of their other targets (dependencies build phases and
    #        frameworks build phases).
    #       - Unrecognized pod groups are removed.
    # 2. All the targets which require it are installed.
    # 3. The support files of the targets are generated and the file references
    #    are created if needed.
    # 4. Any missing Pod target is added to the framework build phases of the
    #    dependent aggregate targets.
    # 5. Any missing target is added to the dependencies build phase of the
    #    dependent target.
    #
    # ## Caveats & Notes
    #
    # - Until CocoaPods 1.0 a migrator will not be provided and when the
    #   structure of the Pods project changes it should be recreated from
    #   scratch.
    # - Although the incremental generation is reasonably robust, if the user
    #   tampers with the Pods project an generation from scratch might be
    #   necessary to bring the project to a consistent state.
    # - Advanced users might workaround to missing features of CocoaPods
    #   editing the project. Those customization might persist for a longer
    #   time than in a system where the project is generated from scratch every
    #   time.
    # - If a Pod changes on any target it needs to be reinstalled from scratch
    #   as the file references might change according to the platform and the
    #   file references installer is not incremental.
    # - The recreation of the target environment header forces the
    #   recompilation of the project.
    #
    #
    # TODO: Fix the CocoaPods compatibility version.
    # TODO: Resource bundle targets are currently removed as they are not
    #       recognized.
    # TODO: The recreation of the prefix header of the Pods targets forces a
    #       recompilation.
    # TODO: The headers search paths of the Pods xcconfigs should not include
    #       all the headers.
    # TODO: Clean system frameworks & libraries not referenced anymore.
    #
    class PodsProjectGenerator

      autoload :FileReferencesInstaller,  'cocoapods/installer/pods_project_generator/file_references_installer'
      autoload :SupportFilesGenerator,    'cocoapods/installer/pods_project_generator/support_files_generator'
      autoload :TargetInstaller,          'cocoapods/installer/pods_project_generator/target_installer'

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

      # @return [Array] The path of the Podfile.
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
        install_targets
        sync_support_files
        add_missing_aggregate_targets_libraries
        add_missing_target_dependencies
        post_installation_cleaning
      end

      # Writes the Pods project to the disk.
      #
      # @return [void]
      #
      def write_project
        UI.message "- Writing Pods project" do
          project.prepare_for_serialization
          project.save
        end
      end

      # @return [Project] the generated Pods project.
      #
      attr_reader :project


      private

      # @!group Installation steps
      #-----------------------------------------------------------------------#

      # Creates the Pods project from scratch.
      #
      # @return [void]
      #
      def prepare_project
        if should_create_new_project?
          UI.message"- Initializing new project" do
            @project = Pod::Project.new(sandbox.project_path)
            @new_project = true
          end
        else
          UI.message"- Opening existing project" do
            @project = Pod::Project.open(sandbox.project_path)
            detect_native_targets
            clean_groups
            clean_native_targets
          end
        end

        project.set_podfile(podfile_path)
        setup_build_configurations
        sandbox.project = project
      end

      # Installs the targets which require an installation.
      #
      # The Pod targets which require an installation (missing, added, or
      # changed) are installed from scratch for all the targets.
      #
      # Only the missing aggregate targets are installed as any reference to
      # any unrecognized target has already be removed, the references in the
      # build phases will be synchronized later and the support files will be
      # regenerated and synchronized in any case.
      #
      # @return [void]
      #
      def install_targets
        pods_to_install.each do |name|
          UI.message"- Installing `#{name}`" do
            add_pod(name)
          end
        end

        aggregate_targets_to_install.each do |target|
          UI.message"- Installing `#{target}`" do
            add_aggregate_target(target)
          end
        end
      end

      # Generates the support for files for the targets and adds the file
      # references to them if needed.
      #
      # @return [void]
      #
      def sync_support_files
        targets = all_pod_targets + aggregate_targets
        targets.reject!(&:skip_installation?)
        targets.each do |target|
          UI.message"- Generating support files for target `#{target}`" do
            gen = SupportFilesGenerator.new(target, sandbox.project)
            gen.generate!
          end
        end
      end

      # Links the aggregate targets with all the dependent pod targets.
      # Aggregate targets are always created from scratch.
      #
      # @return [void]
      #
      def add_missing_aggregate_targets_libraries
        UI.message"- Populating aggregate targets" do
          aggregate_targets.each do |aggregate_target|
            native_target = aggregate_target.native_target
            aggregate_target.pod_targets.each do |pod_target|
              product = pod_target.native_target.product_reference
              unless native_target.frameworks_build_phase.files_references.include?(product)
                native_target.frameworks_build_phase.add_file_reference(product)
              end
            end
          end
        end
      end

      # Synchronizes the dependencies of the targets.
      #
      # @return [void]
      #
      def add_missing_target_dependencies
        UI.message"- Setting-up target dependencies" do
          aggregate_targets.each do |aggregate_target|
            aggregate_target.pod_targets.each do |dep|
              aggregate_target.native_target.add_dependency(dep.target)
            end

            aggregate_targets.each do |aggregate_target|
              aggregate_target.pod_targets.each do |pod_target|
                dependencies = pod_target.dependencies.map { |dep_name| aggregate_target.pod_targets.find { |target| target.pod_name == dep_name } }
                dependencies.each do |dep|
                  pod_target.native_target.add_dependency(dep.target)
                end
              end
            end
          end
        end
      end

      # Removes any system framework not referenced by any target.
      #
      # @return [void]
      #
      def post_installation_cleaning
        project.frameworks_group.files.each do |file|
          only_refered_by_group = file.referrers.count == 1
          if only_refered_by_group
            file.remove_from_project
          end
        end
      end


      private

      # @!group Incremental Editing
      #-----------------------------------------------------------------------#

      # Matches the native targets of the Pods project with the targets
      # generated by the analyzer.
      #
      # @return [void]
      #
      def detect_native_targets
        @native_targets_by_name = project.targets.group_by(&:name)
        @unrecognized_targets = native_targets_by_name.keys.dup
        cp_targets = aggregate_targets + all_pod_targets
        cp_targets.each do |pod_target|
          native_targets = native_targets_by_name[pod_target.label]
          if native_targets
            pod_target.native_target = native_targets.first
            @unrecognized_targets.delete(pod_target.label)
          end
        end
      end

      # Cleans any unrecognized group in the Pods group and in the support
      # files group.
      #
      # @return [void]
      #
      def clean_groups
        pod_names = all_pod_targets.map(&:pod_name).uniq.sort
        groups_to_remove = []
        groups_to_remove << project.pod_groups.reject do |group|
          pod_names.include?(group.display_name)
        end

        groups_to_remove << project.aggregate_groups.map(&:groups).flatten.reject do |group|
          pod_names.include?(group.display_name)
        end

        aggregate_names = aggregate_targets.map(&:label).uniq.sort
        groups_to_remove << project.support_files_group.children.reject do |group|
          aggregate_names.include?(group.display_name)
        end

        groups_to_remove.flatten.each do |group|
          remove_group(group)
        end
      end

      # Cleans the unrecognized native targets.
      #
      # @return [void]
      #
      def clean_native_targets
        unrecognized_targets.each do |target_name|
          remove_target(native_targets_by_name[target_name].first)
        end
      end


      private

      # @!group Private Helpers
      #-----------------------------------------------------------------------#

      # @return [Bool] Whether a new project should be created from scratch or
      #         the installation can be performed incrementally.
      #
      def should_create_new_project?
        # TODO version
        compatbile_version = '0.24.0'
        !sandbox.version_at_least?(compatbile_version) || !sandbox.project_path.exist?
      end

      #
      #
      attr_accessor :new_project
      alias_method  :new_project?, :new_project

      # @return [Array<PodTarget>] The pod targets generated by the installation
      #         process.
      #
      def all_pod_targets
        aggregate_targets.map(&:pod_targets).flatten
      end

      #
      #
      def pods_to_install
        if new_project
          all_pod_targets.map(&:pod_name).uniq.sort
        else
          # TODO: Add missing groups
          missing_target = all_pod_targets.select { |pod_target| pod_target.native_target.nil? }.map(&:pod_name).uniq
          @pods_to_install ||= (sandbox.state.added | sandbox.state.changed | missing_target).uniq.sort
        end
      end

      #
      #
      def aggregate_targets_to_install
        aggregate_targets.sort_by(&:name).select do |target|
          target.native_target.nil? && !target.skip_installation?
        end
      end

      attr_accessor :unrecognized_targets
      attr_accessor :native_targets_by_name

      # Sets the build configuration of the Pods project according the build
      # configurations of the user as detected by the analyzer and other
      # default values.
      #
      # @return [void]
      #
      def setup_build_configurations
        user_build_configurations.each do |name, type|
          project.add_build_configuration(name, type)
        end

        platforms = aggregate_targets.map(&:platform)
        osx_deployment_target = platforms.select { |p| p.name == :osx }.map(&:deployment_target).min
        ios_deployment_target = platforms.select { |p| p.name == :ios }.map(&:deployment_target).min
        project.build_configurations.each do |build_configuration|
          build_configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = osx_deployment_target.to_s if osx_deployment_target
          build_configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = ios_deployment_target.to_s if ios_deployment_target
          build_configuration.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
        end
      end

      # Removes the given group taking care of removing any referenced target.
      #
      # @return [void]
      #
      def remove_group(group)
        UI.message"- Removing `#{group}` group" do
          group.groups.each do |child|
            remove_group(child)
          end

          targets = project.targets.select { |target| group.children.include?(target.product_reference) }
          targets.each do |target|
            remove_target(target)
          end

          group.remove_from_project
        end
      end

      # Removes the given target removing any reference to it from any other
      # target.
      #
      # @return [void]
      #
      def remove_target(target)
        UI.message"- Removing `#{target}` target" do
          target.referrers.each do |ref|
            if ref.isa == 'PBXTargetDependency'
              ref.remove_from_project
            end
          end
          target.remove_from_project

          target.product_reference.referrers.each do |ref|
            if ref.isa == 'PBXBuildFile'
              ref.remove_from_project
            end
          end
          target.product_reference.remove_from_project
        end
      end

      # Installs all the targets of the Pod with the given name. If the Pod
      # already exists it is removed before.
      #
      # @return [void]
      #
      def add_pod(name)
        pod_targets = all_pod_targets.select { |target| target.pod_name == name }

        remove_group(project.pod_group(name)) if project.pod_group(name)
        UI.message"- Installing file references" do
          path = sandbox.pod_dir(name)
          local = sandbox.local?(name)
          project.add_pod_group(name, path, local)

          FileReferencesInstaller.new(sandbox, pod_targets).install!
        end

        pod_targets.each do |target|
          remove_target(target.native_target) if target.native_target
          add_aggregate_target(target)
        end
      end

      # Installs an aggregate target.
      #
      # @return [void]
      #
      def add_aggregate_target(target)
        UI.message "- Installing target `#{target}`" do
          TargetInstaller.new(project, target).install!
        end
      end

      #-----------------------------------------------------------------------#

    end
  end
end
