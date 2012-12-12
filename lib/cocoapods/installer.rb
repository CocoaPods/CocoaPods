module Pod

  # The {Installer} is the core of CocoaPods. This class is responsible of
  # taking a Podfile and transform it in the Pods libraries. This class also
  # integrates the user project so the Pods libraries can be used out of the
  # box.
  #
  # The Installer is capable of doing incremental updates to an existing Pod
  # installation.
  #
  # The Installer gets the information that it needs mainly from 3 files:
  #
  #   - Podfile: The specification written by the user that contains
  #     information about targets and Pods.
  #   - Podfile.lock: Contains information about the pods that were previously
  #     installed and in concert with the Podfile provides information about
  #     which specific version of a Pod should be installed. This file is
  #     ignored in update mode.
  #   - Manifest.lock: A file contained in the Pods folder that keeps track of
  #     the pods installed in the local machine. This files is used once the
  #     exact versions of the Pods has been computed to detect if that version
  #     is already installed. This file is not intended to be kept under source
  #     control and is a copy of the Podfile.lock.
  #
  # Once completed the installer should produce the following file structure:
  #
  #     Pods
  #     |
  #     +-- Headers
  #     |   +-- Build
  #     |   |   +-- [Pod Name]
  #     |   +-- Public
  #     |       +-- [Pod Name]
  #     |
  #     +-- Sources
  #     |   +-- [Pod Name]
  #     |
  #     +-- Specifications
  #     |
  #     +-- Target Support Files
  #     |   +-- [Target Name]
  #     |       +-- Acknowledgements.markdown
  #     |       +-- Acknowledgements.plist
  #     |       +-- Pods.xcconfig
  #     |       +-- Pods-prefix.pch
  #     |       +-- PodsDummy_Pods.m
  #     |
  #     +-- Manifest.lock
  #     |
  #     +-- Pods.xcodeproj
  #
  class Installer
    autoload :TargetInstaller,       'cocoapods/installer/target_installer'
    autoload :UserProjectIntegrator, 'cocoapods/installer/user_project_integrator'

    include Config::Mixin

    # @return [Sandbox] The sandbox where the Pods should be installed.
    #
    attr_reader :sandbox

    # @return [Podfile] The Podfile specification that contains the information
    #         of the Pods that should be installed.
    #
    attr_reader :podfile

    # @return [Lockfile] The Lockfile that stores the information about the
    #         Pods previously installed on any machine.
    #
    attr_reader :lockfile

    # @param [Sandbox]  sandbox     @see sandbox
    # @param [Podfile]  podfile     @see podfile
    # @param [Lockfile] lockfile    @see lockfile
    #
    def initialize(sandbox, podfile, lockfile = nil)
      @sandbox     =  sandbox
      @podfile     =  podfile
      @lockfile    =  lockfile
    end

    # @return [Bool] Whether the installer is in update mode. In update mode
    #         the contents of the Lockfile are not taken into account for
    #         deciding what Pods to install.
    #
    attr_accessor :update_mode

    # Installs the Pods.
    #
    # The installation process of is mostly linear with few minor complications
    # to keep in mind:
    #
    # - The stored podspecs need to be cleaned before the resolution step
    #   otherwise the sandbox might return an old podspec and not download
    #   the new one from an external source.
    # - The resolver might trigger the download of Pods from external sources
    #   necessary to retrieve their podspec (unless it is instructed not to
    #   do it).
    #
    # @note   The order of the steps is very important and should be changed
    #         carefully.
    #
    # @return [void]
    #
    def install!
      analyze
      prepare_for_legacy_compatibility
      clean_global_support_files
      clean_removed_pods
      clean_pods_to_install
      install_dependencies
      install_targets
      write_lockfiles
      integrate_user_project
    end

    # Performs only the computation parts of an installation.
    #
    # It is used by the `outdated` subcommand.
    #
    # @return [void]
    #
    def analyze
      create_libraries
      generate_pods_by_podfile_state
      update_repositories_if_needed
      generate_locked_dependencies
      resolve_dependencies
      generate_local_pods
      generate_pods_that_should_be_installed
    end

    #---------------------------------------------------------------------------#

    # @!group Analysis products

    public

    # @return [Array<String>]
    #   the names of the pods that were added to Podfile since the last
    #   installation on any machine.
    #
    attr_reader :pods_added_from_the_lockfile

    # @return [Array<String>]
    #   the names of the pods whose version requirements in the Podfile are
    #   incompatible with the version stored in the lockfile.
    #
    attr_reader :pods_changed_from_the_lockfile

    # @return [Array<String>]
    #   the names of the pods that were deleted from Podfile since the last
    #   installation on any machine.
    #
    attr_reader :pods_deleted_from_the_lockfile

    # @return [Array<String>]
    #   the names of the pods that didn't change since the last installation on
    #   any machine.
    #
    attr_reader :pods_unchanged_from_the_lockfile

    # @return [Array<Dependency>]
    #   the dependencies generate by the lockfile that prevent the resolver to
    #   update a Pod.
    #
    attr_reader :locked_dependencies

    # @return [Hash{TargetDefinition => Array<Spec>}]
    #   the specifications grouped by target as identified in the
    #   resolve_dependencies step.
    #
    attr_reader :specs_by_target

    # @return [Array<Specification>]
    #   the specifications of the resolved version of Pods that should be
    #   installed.
    #
    attr_reader :specifications

    # @return [Hash{TargetDefinition => Array<LocalPod>}]
    #   the local pod instances grouped by target.
    #
    attr_reader :local_pods_by_target

    # @return [Array<LocalPod>]
    #   the list of LocalPod instances for each dependency sorted by name.
    #
    attr_reader :local_pods

    # @return [Array<String>]
    #   the Pods that should be installed.
    #
    attr_reader :pods_to_install

    #---------------------------------------------------------------------------#

    # @!group Installation products

    public

    # @return [Pod::Project]
    #   the `Pods/Pods.xcodeproj` project.
    #
    attr_reader :pods_project

    # @return [Array<TargetInstaller>]
    #
    attr_reader :target_installers

    #-------------------------------------------------------------------------#

    # @!group Pre-installation computations

    attr_reader :libraries

    private

    def create_libraries
      @libraries = []
      podfile.target_definitions.values.each do |target_definition|
        lib                           = Library.new(target_definition)
        lib.support_files_root        = config.sandbox.root
        if config.integrate_targets?
        lib.user_project_path         = compute_user_project_path(target_definition)
        lib.user_project              = Xcodeproj::Project.new(lib.user_project_path)
        lib.user_targets              = compute_user_project_targets(target_definition, lib.user_project)
        lib.user_build_configurations = compute_user_build_configurations(target_definition, lib.user_targets)
        lib.platform                  = compute_platform_for_taget_definition(target_definition, lib.user_targets)
        else

        lib.user_project_path         = config.project_root
        lib.user_targets              = []
        lib.user_build_configurations = {}
        lib.platform                  = target_definition.platform
        end
        @libraries << lib
      end
    end

    ####################################################################################################

    # Returns the path of the user project that the {TargetDefinition}
    # should integrate.
    #
    # @raise  If the project is implicit and there are multiple projects.
    #
    # @raise  If the path doesn't exits.
    #
    # @return [Pathname] the path of the user project.
    #
    def compute_user_project_path(target_definition)
      if target_definition.user_project_path
        user_project_path = Pathname.new(config.project_root + target_definition.user_project_path)
        unless user_project_path.exist?
          raise Informative, "Unable to find the Xcode project `#{user_project_path}` for the target `#{target_definition.label}`."
        end
      else
        xcodeprojs = Pathname.glob(config.project_root + '*.xcodeproj')
        if xcodeprojs.size == 1
          user_project_path = xcodeprojs.first
        else
          raise Informative, "Could not automatically select an Xcode project. " \
            "Specify one in your Podfile like so:\n\n" \
            "    xcodeproj 'path/to/Project.xcodeproj'\n"
        end
      end
      user_project_path
    end

    # Returns a list of the targets from the project of {TargetDefinition}
    # that needs to be integrated.
    #
    # @note   The method first looks if there is a target specified with
    #         the `link_with` option of the {TargetDefinition}. Otherwise
    #         it looks for the target that has the same name of the target
    #         definition.  Finally if no target was found the first
    #         encountered target is returned (it is assumed to be the one
    #         to integrate in simple projects).
    #
    # @note   This will only return targets that do **not** already have
    #         the Pods library in their frameworks build phase.
    #
    #
    def compute_user_project_targets(target_definition, user_project)
      return [] unless user_project
      if link_with = target_definition.link_with
        targets = user_project.targets.select { |t| link_with.include? t.name }
        raise Informative, "Unable to find a target named `#{link_with.to_sentence}` to link with target definition `#{target_definition.name}`" if targets.empty?
      elsif target_definition.name != :default
        target = user_project.targets.find { |t| t.name == target_definition.name.to_s }
        targets = [ target ].compact
        raise Informative, "Unable to find a target named `#{target_definition.name.to_s}`" if targets.empty?
      else
        targets = [ user_project.targets.first ].compact
        raise Informative, "Unable to find a target" if targets.empty?
      end
      targets
    end

    # @todo Robustness for installations without integration.
    #
    def compute_user_build_configurations(target_definition, user_targets)
      if user_targets
        user_targets.map { |t| t.build_configurations.map(&:name) }.flatten.inject({}) do |hash, name|
          unless name == 'Debug' || name == 'Release'
            hash[name] = :release
          end
          hash
        end.merge(target_definition.build_configurations || {})
      else
        target_definition.build_configurations || {}
      end
    end

    # Returns the platform for the library.
    #
    # @note This resolves to the lowest deployment target across the user targets.
    #
    # @todo Finish implementation
    #
    def compute_platform_for_taget_definition(target_definition, user_targets)
      return target_definition.platform if target_definition.platform
      if user_targets
        name = nil
        deployment_target = nil
        user_targets.each do |target|
          name ||= target.platform_name
          raise "Targets with different platforms" unless name == target.platform_name
          if !deployment_target || deployment_target > Version.new(target.deployment_target)
            deployment_target = Version.new(target.deployment_target)
          end
        end
        platform = Platform.new(name, deployment_target)
        # TODO
        target_definition.platform = platform
      else
        raise Informative, "Missing platform for #{target_definition}."\
          "If no integrating it is necessary to specify a platform."
      end
      platform
    end

    ####################################################################################################

    # Compares the {Podfile} with the {Lockfile} in order to detect which
    # dependencies should be locked.
    #
    # @return [void]
    #
    # @todo If there is not Lockfile all the Pods should be marked as added.
    #
    # @todo Once the manifest.lock is implemented only the unchanged pods
    #       should be tracked.
    #
    def generate_pods_by_podfile_state
      if lockfile
        UI.section "Finding added, modified or removed dependencies:" do
          pods_by_state = lockfile.detect_changes_with_podfile(podfile)
          @pods_added_from_the_lockfile     = pods_by_state[:added]     || []
          @pods_deleted_from_the_lockfile   = pods_by_state[:removed]   || []
          @pods_changed_from_the_lockfile   = pods_by_state[:changed]   || []
          @pods_unchanged_from_the_lockfile = pods_by_state[:unchanged] || []
          display_pods_by_lockfile_state
        end
      else
        @pods_added_from_the_lockfile     = []
        @pods_deleted_from_the_lockfile   = []
        @pods_changed_from_the_lockfile   = []
        @pods_unchanged_from_the_lockfile = []
      end
    end

    # Displays the state of each dependency.
    #
    # @return [void]
    #
    def display_pods_by_lockfile_state
      return unless config.verbose?
      pods_added_from_the_lockfile      .each { |pod| UI.message("A".green  + "#{pod}", '', 2) }
      pods_deleted_from_the_lockfile    .each { |pod| UI.message("R".red    + "#{pod}", '', 2) }
      pods_changed_from_the_lockfile    .each { |pod| UI.message("M".yellow + "#{pod}", '', 2) }
      pods_unchanged_from_the_lockfile  .each { |pod| UI.message("-"        + "#{pod}", '', 2) }
    end

    # Lazily updates the source repositories. The update is triggered if:
    #
    # - There are pods that changed in the Podfile.
    # - The lockfile is missing.
    # - The installer is in update_mode.
    #
    # @todo Remove the lockfile condition once compare_podfile_and_lockfile
    #       is updated.
    #
    # @todo Lazy resolution can't be done if we want to fully support detection
    #       of changes in specifications checksum.
    #
    # @return [void]
    #
    def update_repositories_if_needed
      return if config.skip_repo_update?
      changed_pods = (pods_changed_from_the_lockfile + pods_deleted_from_the_lockfile)
      should_update = !lockfile || !changed_pods.empty? || update_mode
      if should_update
        UI.section 'Updating spec repositories' do
          Command::Repo.new(Command::ARGV.new(["update"])).run
        end
      end
    end

    # Generates dependencies that require the specific version of the Pods that
    # haven't changed in the {Lockfile}.
    #
    # These dependencies are passed to the {Resolver}, unless the installer is
    # in update mode, to prevent it from upgrading the Pods that weren't
    # changed in the {Podfile}.
    #
    # @return [void]
    #
    def generate_locked_dependencies
      @locked_dependencies = pods_unchanged_from_the_lockfile.map do |pod|
        lockfile.dependency_to_lock_pod_named(pod)
      end
    end

    # Converts the Podfile in a list of specifications grouped by target.
    #
    # @note   As some dependencies might have external sources the resolver is
    #         aware of the {Sandbox} and interacts with it to download the
    #         podspecs of the external sources. This is necessary because the
    #         resolver needs the specifications to analyze their dependencies
    #         (which might be from external sources).
    #
    # @note   In update mode the resolver is set to always update the specs
    #         from external sources.
    #
    # @return [void]
    #
    def resolve_dependencies
      UI.section "Resolving dependencies of #{UI.path podfile.defined_in_file}" do
        locked_deps = update_mode ? [] : locked_dependencies
        resolver = Resolver.new(sandbox, podfile, locked_deps)
        resolver.update_external_specs = update_mode
        @specs_by_target = resolver.resolve
        @specifications  = specs_by_target.values.flatten
      end
    end


    # Computes the list of the Pods that should be installed or reinstalled in
    # the {Sandbox}.
    #
    # The pods to install are identified as the Pods that don't exist in the
    # sandbox or the Pods whose version differs from the one of the lockfile.
    #
    # In update mode specs originating from external dependencies and or from
    # head sources are always reinstalled.
    #
    # @return [void]
    #
    # @todo Use {Sandbox} manifest.
    #
    # @todo [#534] Detect if the folder of a Pod is empty.
    #
    def generate_pods_that_should_be_installed
      changed_pods_names = []
      if lockfile
        changed_pods = local_pods.select do |pod|
          pod.top_specification.version != lockfile.pod_versions[pod.name]
        end
        if update_mode
          changed_pods_names += pods.select do |pods|
            pod.top_specification.version.head? ||
              resolver.pods_from_external_sources.include?(pod.name)
          end
        end
        changed_pods_names += pods_added_from_the_lockfile + pods_changed_from_the_lockfile
      else
        changed_pods = local_pods
      end

      not_existing_pods = local_pods.reject { |pod| pod.exists? }
      @pods_to_install = (changed_pods + not_existing_pods).uniq
    end


    # Converts the specifications produced by the Resolver in local pods.
    #
    # The LocalPod class is responsible to handle the concrete representation
    # of a specification in the {Sandbox}.
    #
    # @return [void]
    #
    # @todo [#535] Pods should be accumulated per Target, also in the Local
    #       Pod class. The Local Pod class should have a method to add itself
    #       to a given project so it can use the sources of all the activated
    #       podspecs across all targets. Also cleaning should take into account
    #       that.
    #
    def generate_local_pods
      @local_pods_by_target = {}
      specs_by_target.each do |target_definition, specs|
        @local_pods_by_target[target_definition] = specs.map do |spec|
          if spec.local?
            sandbox.locally_sourced_pod_for_spec(spec, target_definition.platform)
          else
            sandbox.local_pod_for_spec(spec, target_definition.platform)
          end
        end.uniq.compact
      end

      @local_pods = local_pods_by_target.values.flatten.uniq.sort_by { |pod| pod.name.downcase }
    end

    #---------------------------------------------------------------------------#

    # @!group Installation

    private

    # Prepares the Pods folder in order to be compatible with the most recent
    # version of CocoaPods.
    #
    # @return [void]
    #
    def prepare_for_legacy_compatibility
      # move_target_support_files_if_needed
      # copy_lock_file_to_Pods_lock_if_needed
      # move_Local_Podspecs_to_Podspecs_if_needed
      # move_pods_to_sources_folder_if_needed
    end

    # @return [void] In this step we clean all the folders that will be
    #   regenerated from scratch and any file which might not be overwritten.
    #
    # @todo Clean the podspecs of all the pods that aren't unchanged so the
    #        resolution process doesn't get confused by them.
    #
    def clean_global_support_files
      sandbox.prepare_for_install
    end

    # @return [void] In this step we clean all the files related to the removed
    #   Pods.
    #
    # @todo Use the local pod implode.
    # @todo [#534] Clean all the Pods folder that are not unchanged?
    #
    def clean_removed_pods
      UI.section "Removing deleted dependencies" do
        pods_deleted_from_the_lockfile.each do |pod_name|
          UI.section("Removing #{pod_name}", "-> ".red) do
            path = sandbox.root + pod_name
            path.rmtree if path.exist?
          end
        end
      end unless pods_deleted_from_the_lockfile.empty?
    end

    # @return [void] In this step we clean the files of the Pods that will be
    #   installed. We clean the files that might affect the resolution process
    #   and the files that might not be overwritten.
    #
    # @todo [#247] Clean the headers of only the pods to install.
    #
    def clean_pods_to_install

    end

    # @return [void] Install the Pods. If the resolver indicated that a Pod
    #   should be installed and it exits, it is removed an then reinstalled. In
    #   any case if the Pod doesn't exits it is installed.
    #
    def install_dependencies
      UI.section "Downloading dependencies" do
        local_pods.each do |pod|
          if pods_to_install.include?(pod)
            UI.section("Installing #{pod}".green, "-> ".green) do
              install_local_pod(pod)
            end
          else
            UI.section("Using #{pod}", "-> ".green)
          end
        end
      end
    end

    # @return [void] Downloads, clean and generates the documentation of a pod.
    #
    # @note The docs need to be generated before cleaning because the
    #       documentation is created for all the subspecs.
    #
    # @note In this step we clean also the Pods that have been pre-downloaded
    #       in AbstractExternalSource#specification_from_sandbox.
    #
    # @todo [#529] Podspecs should not be preserved anymore to prevent user
    #       confusion. Currently we are copying the ones form external sources
    #       in `Local Podspecs` and this feature is not needed anymore.
    #       I think that copying all the used podspecs would be helpful for
    #       debugging.
    #
    def install_local_pod(pod)
      unless pod.downloaded?
        pod.implode
        download_pod(pod)
      end
      generate_docs_if_needed(pod)
      pod.clean! if config.clean?
    end

    # Downloads a Pod forcing the `bleeding edge' version if requested.
    #
    # @return [void]
    #
    def download_pod(pod)
      downloader = Downloader.for_target(pod.root, pod.top_specification.source.dup)
      downloader.cache_root = "~/Library/Caches/CocoaPods"
      downloader.max_cache_size = 500
      if pod.top_specification.version.head?
        downloader.download_head
      else
        downloader.download
      end
      pod.downloaded = true
    end

    # Generates the documentation of a Pod unless it exists for a given
    # version.
    #
    # @return [void]
    #
    def generate_docs_if_needed(pod)
      doc_generator = Generator::Documentation.new(pod)
      if ( config.generate_docs? && !doc_generator.already_installed? )
        UI.section " > Installing documentation"
        doc_generator.generate(config.doc_install?)
      else
        UI.section " > Using existing documentation"
      end
    end

    # Creates and populates the targets of the pods project.
    #
    # @note   Post install hooks run _before_ saving of project, so that they
    #         can alter it before it is writtent to the disk.
    #
    # @return [void]
    #
    def install_targets
      UI.section "Generating support files" do
        prepare_pods_project
        generate_target_installers
        add_source_files_to_pods_project
        run_pre_install_hooks
        generate_target_support_files
        run_post_install_hooks
        write_pod_project
      end
    end

    # Creates the Pods project from scratch if it doesn't exists.
    #
    # @todo Restore the build configuration support.
    # @todo Clean and modify the project if it exists.
    #
    # @return [void]
    #
    def prepare_pods_project
      UI.message "- Creating Pods project" do
        @pods_project = Pod::Project.new(config.sandbox)
        if config.project_podfile.exist?
          @pods_project.add_podfile(config.project_podfile)
        end
      end
    end

    # Creates a target installer for each definition not empty.
    #
    # @return [void]
    #
    def generate_target_installers
      @target_installers = podfile.target_definitions.values.map do |definition|
        pods_for_target = local_pods_by_target[definition]
        libray = libraries.find {|l| l.target_definition == definition }
        TargetInstaller.new(pods_project, libray, pods_for_target) unless definition.empty?
      end.compact
    end

    # Adds the source files of the Pods to the Pods project.
    #
    # The source files are grouped by Pod and in turn by subspec
    # (recursively). Pods are generally added to the `Pods` group, however, if
    # they have a local source they are added to the `Local Pods` group.
    #
    # @return [void]
    #
    # @todo   Clean the groups of the deleted Pods and add only the Pods that
    #         should be installed.
    # @todo   [#588] Add file references for the resources of the Pods as well
    #         so they are visible for the user.
    #
    def add_source_files_to_pods_project
      UI.message "- Adding source files to Pods project" do
        local_pods.each { |p| p.add_file_references_to_project(pods_project) }
        local_pods.each { |p| p.link_headers }
      end
    end

    # Runs the pre install hooks of the installed specs and of the Podfile.
    #
    # @todo   Run the hooks only for the installed pods.
    # @todo   Print a messsage with the names of the specs.
    #
    # @return [void]
    #
    def run_pre_install_hooks
      UI.message "- Running pre install hooks" do
        local_pods_by_target.each do |target_definition, pods|
          pods.each do |pod|
            pod.top_specification.pre_install!(pod, target_definition)
          end
        end
        @podfile.pre_install!(self)
      end
    end

    # Runs the post install hooks of the installed specs and of the Podfile.
    #
    # @todo   Run the hooks only for the installed pods.
    # @todo   Print a message with the names of the specs.
    #
    # @return [void]
    #
    def run_post_install_hooks
      UI.message "- Running post install hooks" do
        target_installers.each do |target_installer|
          specs_by_target[target_installer.library.target_definition].each do |spec|
            spec.post_install!(target_installer)
          end
        end
        @podfile.post_install!(self)
      end
    end

    # Installs the targets of the Pods projects and generates their support
    # files.
    #
    # @todo Move the acknowledgements to the target installer?
    #
    def generate_target_support_files
      UI.message"- Installing targets" do
        target_installers.each do |target_installer|
          pods_for_target = local_pods_by_target[target_installer.library.target_definition]
          target_installer.install!
          acknowledgements_path = target_installer.library.acknowledgements_path
          Generator::Acknowledgements.new(target_installer.library.target_definition,
                                          pods_for_target).save_as(acknowledgements_path)
          generate_dummy_source(target_installer)
        end
      end
    end

    # Generates a dummy source file for each target so libraries that contain
    # only categories build.
    #
    # @todo Move to the target installer?
    #
    def generate_dummy_source(target_installer)
      class_name_identifier = target_installer.library.label
      dummy_source = Generator::DummySource.new(class_name_identifier)
      filename = "#{dummy_source.class_name}.m"
      pathname = Pathname.new(sandbox.root + filename)
      dummy_source.save_as(pathname)
      file = pods_project.new_file(filename, "Targets Support Files")
      target_installer.target.source_build_phase.add_file_reference(file)
    end

    # Writes the Pods project to the disk.
    #
    # @return [void]
    #
    def write_pod_project
      UI.message "- Writing Xcode project file to #{UI.path @sandbox.project_path}" do
        pods_project.save_as(@sandbox.project_path)
      end
    end

    # Writes the Podfile and the {Sandbox} lock files.
    #
    # @return [void]
    #
    # @todo [#552] Implement manifest.
    #
    def write_lockfiles
      @lockfile = Lockfile.generate(podfile, specs_by_target.values.flatten)
      UI.message "- Writing Lockfile in #{UI.path config.project_lockfile}" do
        @lockfile.write_to_disk(config.project_lockfile)
      end

      # UI.message "- Writing Manifest in #{UI.path sandbox.manifest_path}" do
      #   @lockfile.write_to_disk(sandbox.manifest_path)
      # end
    end

    # Integrates the user project.
    #
    # The following actions are performed:
    #   - libraries are added.
    #   - the build script are added.
    #   - the xcconfig files are set.
    #
    # @return [void]
    #
    # @todo [#397] The libraries should be cleaned and the re-added on every
    #       installation. Maybe a clean_user_project phase should be added.
    #
    # @todo [#588] The resources should be added through a build phase instead
    #       of using a script.
    #
    def integrate_user_project
      return unless config.integrate_targets?
      UserProjectIntegrator.new(podfile, pods_project, config.project_root, libraries).integrate!
    end
  end
end
