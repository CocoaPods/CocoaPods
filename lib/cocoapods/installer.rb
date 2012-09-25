module Pod

  # The installer is the core of CocoaPods. This class is responsible of taking
  # a Podfile and transform it in the Pods libraries. This class also
  # integrates the user project so the Pods libraries can be used out of the
  # box.
  #
  # The installer is capable of doing incremental updates to an existing Pod
  # installation.
  #
  # The installer gets the information that it needs mainly from 3 files:
  #
  #   - Podfile: The specification written by the user that contains
  #     information about targets and Pods.
  #   - Podfile.lock: Contains information about the pods that were previously
  #     installed and in concert with the Podfile provides information about
  #     which specific version of a Pod should be installed. This file is
  #     ignored in update mode.
  #   - Pods.lock: A file contained in the Pods folder that keeps track
  #     of the pods installed in the local machine. This files is used once
  #     the exact versions of the Pods has been computed to detect if that
  #     version is already installed. This file is not intended to be kept
  #     under source control and is a copy of the Podfile.lock.
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
  #     +-- Pods.lock
  #     |
  #     +-- Pods.xcodeproj
  #
  class Installer
    autoload :TargetInstaller,       'cocoapods/installer/target_installer'
    autoload :UserProjectIntegrator, 'cocoapods/installer/user_project_integrator'

    include Config::Mixin

    # @return [Sandbox]   The sandbox where to install the Pods.
    #
    attr_reader :sandbox

    # @return [Podfile]   The Podfile specification that contains the
    #                     information of the Pods that should be installed.
    #
    attr_reader :podfile

    # @return [Lockfile]  The Lockfile that stores the information about the
    #                     installed Pods.
    #
    attr_reader :lockfile

    # @return [Bool]      Whether the installer is in update mode. In update
    #                     mode the contents of the Lockfile are not taken into
    #                     account for deciding what Pods to install.
    #
    attr_reader :update_mode

    # @param [Sandbox]  sandbox     @see sandbox
    # @param [Podfile]  podfile     @see podfile
    # @param [Lockfile] lockfile    @see lockfile
    # @param [Bool]     update_mode @see update_mode
    #
    def initialize(sandbox, podfile, lockfile = nil, update_mode = false)
      @sandbox     =  sandbox
      @podfile     =  podfile
      @lockfile    =  lockfile
      @update_mode =  update_mode
    end

    # @return [void] The installation process of is mostly linear with few
    #   minor complications to keep in mind:
    #
    #   - The stored podspecs need to be cleaned before the resolution step
    #     otherwise the sandbox might return an old podspec and not download
    #     the new one from an external source.
    #   - The resolver might trigger the download of Pods from external sources
    #     necessary to retrieve their podspec (unless it is instructed not to
    #     do it).
    #
    # @note The order of the steps is very important and should be changed
    #       carefully.
    #
    # TODO:
    #
    def install!
      # TODO: prepare_for_legacy_compatibility
      compare_podfile_and_lockfile

      clean_global_support_files
      clean_removed_pods
      clean_pods_to_install

      update_repositories_if_needed
      generate_locked_dependencies
      resolve_dependencies

      # TODO: detect_installed_versions
      create_local_pods
      detect_pods_to_install
      install_dependencies

      generate_support_files
      write_lockfile
      # TODO: write_sandbox_lockfile

      integrate_user_project
    end

    # @return [void] the
    #
    def dry_run

    end



    # @!group Prepare for legacy compatibility

    # @return [void] In this step we prepare the Pods folder in order to be
    #   compatible with the most recent version of CocoaPods.
    #
    # @note This step should be removed by version 1.0.
    #
    def prepare_for_legacy_compatibility
      # move_target_support_files_if_needed
      # copy_lock_file_to_Pods_lock_if_needed
      # move_Local_Podspecs_to_Podspecs_if_needed
      # move_pods_to_sources_folder_if_needed
    end



    # @!group Detect Podfile changes step

    # @return [Hash{Symbol => Array<Spec>}] The name of the pods directly
    #   specified in the Podfile grouped by a symbol representing their state
    #   (added, changed, removed, unchanged) as identified by the {Lockfile}.
    #
    attr_reader :pods_by_state

    # @return [void] In this step the podfile is compared with the lockfile in
    #   order to detect which dependencies should be locked.
    #
    # #TODO: If there is not lockfile all the Pods should be marked as added.
    # #TODO: This should use the Pods.lock file because they are used by the
    #        to detect what needs to be installed.
    #
    def compare_podfile_and_lockfile
      if lockfile
        UI.section "Finding added, modified or removed dependencies:" do
          @pods_by_state = lockfile.detect_changes_with_podfile(podfile)
          display_dependencies_state
        end
      else
        @pods_by_state = {}
      end
    end

    # @return [void] Displays the state of each dependency.
    #
    def display_dependencies_state
      return unless config.verbose?
      marks = { :added => "A".green,
                :changed => "M".yellow,
                :removed => "R".red,
                :unchanged => "-" }
      pods_by_state.each do |symbol, pod_names|
        pod_names.each do |pod_name|
          UI.message("#{marks[symbol]} #{pod_name}", '',2)
        end
      end
    end



    # @!group Cleaning steps

    # @return [void] In this step we clean all the folders that will be
    #   regenerated from scratch and any file which might not be overwritten.
    #
    # @TODO: Clean the podspecs of all the pods that aren't unchanged so the
    #        resolution process doesn't get confused by them.
    #
    def clean_global_support_files
      sandbox.prepare_for_install
    end

    # @return [void] In this step we clean all the files related to the removed
    #   Pods.
    #
    # @TODO: Use the local pod implode.
    # @TODO: [#534] Clean all the Pods folder that are not unchanged?
    #
    def clean_removed_pods
      UI.section "Removing deleted dependencies" do
        pods_by_state[:removed].each do |pod_name|
          UI.section("Removing #{pod_name}", "-> ".red) do
            path = sandbox.root + pod_name
            path.rmtree if path.exist?
          end
        end
      end unless pods_by_state[:removed].empty?
    end

    # @return [void] In this step we clean the files of the Pods that will be
    #   installed. We clean the files that might affect the resolution process
    #   and the files that might not be overwritten.
    #
    # @TODO: [#247] Clean the headers of only the pods to install.
    #
    def clean_pods_to_install
    end



    # @!group Generate locked dependencies step

    # @return [void] Lazily updates the source repositories. The update is
    #   triggered if:
    #   - There are pods that changed in the Podfile.
    #   - The lockfile is missing.
    #   - The installer is in update_mode.
    #
    # TODO: Remove the lockfile condition once compare_podfile_and_lockfile
    #       is updated.
    #
    def update_repositories_if_needed
      return if config.skip_repo_update?
      changed_pods = (pods_by_state[:added] + pods_by_state[:changed])
      UI.section 'Updating spec repositories' do
        Command::Repo.new(Command::ARGV.new(["update"])).run
      end if !lockfile || !changed_pods.empty? || update_mode
    end

    # @!group Generate locked dependencies step

    # @return [Array<Specification>]  All dependencies that have been resolved.
    #
    attr_reader :locked_dependencies

    # @return [void] In this step we generate the dependencies of necessary to
    #   prevent the resolver from updating the pods which are in unchanged
    #   state. The Podfile is compared to the Podfile.lock to detect what
    #   version of a dependency should be locked.
    #
    def generate_locked_dependencies
      if update_mode
        @locked_dependencies = []
      else
        @locked_dependencies = pods_by_state[:unchanged].map do |pod_name|
          lockfile.dependency_for_installed_pod_named(pod_name)
        end
      end
    end



    # @!group Resolution steps

    # @return [Hash{Podfile::TargetDefinition => Array<Spec>}]
    #                     The specifications grouped by target as identified in
    #                     the resolve_dependencies step.
    #
    attr_reader :specs_by_target

    # @return [Array<Specification>]  All dependencies that have been resolved.
    #
    attr_reader :specifications

    # @return [void] Converts the Podfile in a list of specifications grouped
    #   by target.
    #
    #   In update mode the specs from external sources are always downloaded.
    #
    def resolve_dependencies
      UI.section "Resolving dependencies of #{UI.path podfile.defined_in_file}" do
        resolver = Resolver.new(sandbox, podfile, locked_dependencies)
        resolver.update_external_specs = update_mode
        @specs_by_target = resolver.resolve
        @specifications  = specs_by_target.values.flatten
      end
    end



    # @!group Detect Pods to install step

    # @return [Array<String>] The names of the Pods that should be installed.
    #
    attr_reader :pods_to_install

    # @return [<void>] In this step the pods to install are detected.
    #   The pods to install are identified as the Pods that don't exist in the
    #   sandbox or the Pods whose version differs from the one of the lockfile.
    #
    #   In update mode specs originating from external dependencies and or from
    #   head sources are always reinstalled.
    #
    #   TODO: Decide a how the Lockfile should report versions.
    #   TODO: [#534] Detect if the folder of a Pod is empty.
    #
    def detect_pods_to_install
      changed_pods_names = []
      if lockfile
        changed_pods = pods.select do |pod|
          pod.top_specification.version != lockfile.pods_versions[pod.name]
        end
        if update_mode
          changed_pods_names += pods.select do |pods|
            pod.top_specification.version.head? ||
              resolver.pods_from_external_sources.include?(pod.name)
          end
        end
        changed_pods_names += @pods_by_state[:added] + @pods_by_state[:changed]
      else
        changed_pods = pods
      end

      not_existing_pods = pods.reject { |pod| pod.exists? }
      @pods_to_install = (changed_pods + not_existing_pods).uniq
    end



    # @!group Install step

    # @return [Hash{Podfile::TargetDefinition => Array<LocalPod>}]
    #
    attr_reader :pods_by_target

    # @return [Array<LocalPod>]  A list of LocalPod instances for each
    #                            dependency sorted by name.
    #                            (that is not a download-only one?)
    attr_reader :pods

    # @return [void] In this step the specifications obtained by the resolver
    #   are converted in local pods. The LocalPod class is responsible to
    #   handle the concrete representation of a specification a sandbox.
    #
    # @TODO: [#535] Pods should be accumulated per Target, also in the Local
    #        Pod class. The Local Pod class should have a method to add itself
    #        to a given project so it can use the sources of all the activated
    #        podspecs across all targets. Also cleaning should take into
    #        account that.
    #
    def create_local_pods
      @pods_by_target = {}
      specs_by_target.each do |target_definition, specs|
        @pods_by_target[target_definition] = specs.map do |spec|
          if spec.local?
            sandbox.locally_sourced_pod_for_spec(spec, target_definition.platform)
          else
            sandbox.local_pod_for_spec(spec, target_definition.platform)
          end
        end.uniq.compact
      end

      @pods = pods_by_target.values.flatten.uniq.sort_by { |pod| pod.name.downcase }
    end



    # @!group Install step

    # @return [void] Install the Pods. If the resolver indicated that a Pod
    #   should be installed and it exits, it is removed an then reinstalled. In
    #   any case if the Pod doesn't exits it is installed.
    #
    def install_dependencies
      UI.section "Downloading dependencies" do
        pods.each do |pod|
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
    # TODO: [#529] Podspecs should not be preserved anymore to prevent user
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

    # @return [void] Downloads a Pod forcing the `bleeding edge' version if
    #   requested.
    #
    def download_pod(pod)
      downloader = Downloader.for_pod(pod)
      if pod.top_specification.version.head?
        if downloader.respond_to?(:download_head)
          downloader.download_head
        else
          raise Informative,
            "The downloader of class `#{downloader.class.name}' does not" \
            "support the `:head' option."
        end
      else
        downloader.download
      end
      pod.downloaded = true
    end

    # @return [void] Generates the documentation of a Pod unless it exists
    #   for a given version.
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



    # @!group Generate Pods project and support files step

    # @return [void] Creates and populates the targets of the pods project.
    #
    # @note Post install hooks run _before_ saving of project, so that they can
    #       alter it before saving.
    #
    def generate_support_files
      UI.section "Generating support files" do
        prepare_pods_project
        add_source_files_to_pods_project
        run_pre_install_hooks
        generate_target_support_files
        run_post_install_hooks
        write_pod_project
      end
    end

    # @return [Project] The Pods project.
    #
    attr_reader :pods_project

    # @return [void] In this step we create the Pods project from scratch if it
    #   doesn't exists. If the Pods project exists instead we clean it and
    #   prepare it for installation.
    #
    def prepare_pods_project
      UI.message "- Creating Pods project" do
        @pods_project = Pod::Project.new
        pods_project.user_build_configurations = podfile.user_build_configurations
        pods_project.main_group.groups.new('name' => 'Targets Support Files')
      end
    end

    # @return [void] In this step we add the source files of the Pods to the
    #   Pods project. The source files are grouped by Pod and in turn by subspec
    #   (recursively). Pods are generally added to the Pods group. However, if
    #   they are local they are added to the Local Pods group.
    #
    # @TODO [#143] This step is quite slow and should be made incremental by
    #       modifying only the files of the changed pods. Xcodeproj deletion
    #       and sorting of folders is required.
    #
    def add_source_files_to_pods_project
      UI.message "- Adding source files to Pods project" do
        pods.each do |pod|
          pod.relative_source_files_by_spec.each do |spec, paths|
            if pod.local?
              parent_group = pods_project.local_pods
            else
              parent_group = pods_project.pods
            end
            group = pods_project.add_spec_group(spec.name, parent_group)
            paths.each do |path|
              group.files.new('path' => path.to_s)
            end
          end
        end
      end
    end

    def target_installers
      @target_installers ||= podfile.target_definitions.values.map do |definition|
        TargetInstaller.new(podfile, pods_project, definition) unless definition.empty?
      end.compact
    end

    def run_pre_install_hooks
      UI.message "- Running pre install hooks" do
        pods_by_target.each do |target_definition, pods|
          pods.each do |pod|
            pod.top_specification.pre_install(pod, target_definition)
          end
        end
        @podfile.pre_install!(self)
      end
    end

    def run_post_install_hooks
      UI.message "- Running post install hooks" do
        # we loop over target installers instead of pods, because we yield the
        # target installer to the spec post install hook.
        target_installers.each do |target_installer|
          specs_by_target[target_installer.target_definition].each do |spec|
            spec.post_install(target_installer)
          end
        end
        @podfile.post_install!(self)
      end
    end

    def generate_target_support_files
      UI.message"- Installing targets" do
        target_installers.each do |target_installer|
          pods_for_target = pods_by_target[target_installer.target_definition]
          target_installer.install!(pods_for_target, sandbox)
          acknowledgements_path = target_installer.target_definition.acknowledgements_path
          Generator::Acknowledgements.new(target_installer.target_definition,
                                          pods_for_target).save_as(acknowledgements_path)
          generate_dummy_source(target_installer)
        end
      end
    end

    def generate_dummy_source(target_installer)
      class_name_identifier = target_installer.target_definition.label
      dummy_source = Generator::DummySource.new(class_name_identifier)
      filename = "#{dummy_source.class_name}.m"
      pathname = Pathname.new(sandbox.root + filename)
      dummy_source.save_as(pathname)

      project_file = pods_project.files.new('path' => filename)
      pods_project.group("Targets Support Files") << project_file

      target_installer.target.source_build_phases.first << project_file
    end

    def write_pod_project
      UI.message "- Writing Xcode project file to #{UI.path @sandbox.project_path}" do
        pods_project.save_as(@sandbox.project_path)
      end
    end



    # @!group Lockfile related steps

    def write_lockfile
      UI.message "- Writing Lockfile in #{UI.path config.project_lockfile}" do
        @lockfile = Lockfile.generate(podfile, specs_by_target.values.flatten)
        @lockfile.write_to_disk(config.project_lockfile)
      end
    end

    # @TODO: [#552] Implement
    #
    def write_sandbox_lockfile

    end

    # @!group Integrate user project step

    # @return [void] In this step the user project is integrated. The Pods
    # libraries are added, the build script are added, and the xcconfig files
    # are set.
    #
    # @TODO: [#397] The libraries should be cleaned and the re-added on every
    #        install. Maybe a clean_user_project phase should be added.
    #
    def integrate_user_project
      UserProjectIntegrator.new(podfile).integrate! if config.integrate_targets?
    end
  end
end
