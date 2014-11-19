require 'active_support/core_ext/string/inflections'

module Pod
  # The Installer is responsible of taking a Podfile and transform it in the
  # Pods libraries. It also integrates the user project so the Pods
  # libraries can be used out of the box.
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
  # The Installer is designed to work in environments where the Podfile folder
  # is under source control and environments where it is not. The rest of the
  # files, like the user project and the workspace are assumed to be under
  # source control.
  #
  class Installer
    autoload :AggregateTargetInstaller, 'cocoapods/installer/target_installer/aggregate_target_installer'
    autoload :Analyzer,                 'cocoapods/installer/analyzer'
    autoload :FileReferencesInstaller,  'cocoapods/installer/file_references_installer'
    autoload :HooksContext,             'cocoapods/installer/hooks_context'
    autoload :Migrator,                 'cocoapods/installer/migrator'
    autoload :PodSourceInstaller,       'cocoapods/installer/pod_source_installer'
    autoload :PodTargetInstaller,       'cocoapods/installer/target_installer/pod_target_installer'
    autoload :TargetInstaller,          'cocoapods/installer/target_installer'
    autoload :UserProjectIntegrator,    'cocoapods/installer/user_project_integrator'

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

    # @param  [Sandbox]  sandbox     @see sandbox
    # @param  [Podfile]  podfile     @see podfile
    # @param  [Lockfile] lockfile    @see lockfile
    #
    def initialize(sandbox, podfile, lockfile = nil)
      @sandbox  = sandbox
      @podfile  = podfile
      @lockfile = lockfile
    end

    # @return [Hash, Boolean, nil] Pods that have been requested to be
    #         updated or true if all Pods should be updated.
    #         If all Pods should been updated the contents of the Lockfile are
    #         not taken into account for deciding what Pods to install.
    #
    attr_accessor :update

    # Installs the Pods.
    #
    # The installation process is mostly linear with a few minor complications
    # to keep in mind:
    #
    # - The stored podspecs need to be cleaned before the resolution step
    #   otherwise the sandbox might return an old podspec and not download
    #   the new one from an external source.
    # - The resolver might trigger the download of Pods from external sources
    #   necessary to retrieve their podspec (unless it is instructed not to
    #   do it).
    #
    # @return [void]
    #
    def install!
      prepare
      resolve_dependencies
      download_dependencies
      generate_pods_project
      integrate_user_project if config.integrate_targets?
      perform_post_install_actions
    end

    def prepare
      UI.message 'Preparing' do
        sandbox.prepare
        Migrator.migrate(sandbox)
      end
    end

    def resolve_dependencies
      UI.section 'Analyzing dependencies' do
        analyze
        validate_build_configurations
        prepare_for_legacy_compatibility
        clean_sandbox
      end
    end

    def download_dependencies
      UI.section 'Downloading dependencies' do
        create_file_accessors
        install_pod_sources
        run_pre_install_hooks
        clean_pod_sources
      end
    end

    def generate_pods_project
      UI.section 'Generating Pods project' do
        prepare_pods_project
        install_file_references
        install_libraries
        set_target_dependencies
        run_podfile_post_install_hooks
        write_pod_project
        write_lockfiles
      end
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Installation results

    # @return [Analyzer] the analyzer which provides the information about what
    #         needs to be installed.
    #
    attr_reader :analysis_result

    # @return [Pod::Project] the `Pods/Pods.xcodeproj` project.
    #
    attr_reader :pods_project

    # @return [Array<String>] The Pods that should be installed.
    #
    attr_reader :names_of_pods_to_install

    # @return [Array<AggregateTarget>] The Podfile targets containing library
    #         dependencies.
    #
    attr_reader :aggregate_targets

    # @return [Array<Specification>] The specifications that where installed.
    #
    attr_accessor :installed_specs

    #-------------------------------------------------------------------------#

    private

    # @!group Installation steps

    # @return [void]
    #
    # @note   The warning about the version of the Lockfile doesn't use the
    #         `UI.warn` method because it prints the output only at the end
    #         of the installation. At that time CocoaPods could have crashed.
    #
    def analyze
      if lockfile && lockfile.cocoapods_version > Version.new(VERSION)
        STDERR.puts '[!] The version of CocoaPods used to generate ' \
          "the lockfile (#{lockfile.cocoapods_version}) is "\
          "higher than the version of the current executable (#{VERSION}). " \
          'Incompatibility issues may arise.'.yellow
      end

      analyzer = Analyzer.new(sandbox, podfile, lockfile)
      analyzer.update = update
      @analysis_result = analyzer.analyze
      @aggregate_targets = analyzer.result.targets
    end

    # Ensures that the white-listed build configurations are known to prevent
    # silent typos.
    #
    # @raise  If a unknown user configuration is found.
    #
    def validate_build_configurations
      whitelisted_configs = pod_targets.map do |target|
        target.target_definition.all_whitelisted_configurations.map(&:downcase)
      end.flatten.uniq
      all_user_configurations = analysis_result.all_user_build_configurations.keys.map(&:downcase)

      remainder = whitelisted_configs - all_user_configurations
      unless remainder.empty?
        raise Informative, "Unknown #{'configuration'.pluralize(remainder.size)} whitelisted: #{remainder.sort.to_sentence}."
      end
    end

    # Prepares the Pods folder in order to be compatible with the most recent
    # version of CocoaPods.
    #
    # @return [void]
    #
    def prepare_for_legacy_compatibility
      # move_target_support_files_if_needed
      # move_Local_Podspecs_to_Podspecs_if_needed
      # move_pods_to_sources_folder_if_needed
    end

    # @return [void] In this step we clean all the folders that will be
    #         regenerated from scratch and any file which might not be
    #         overwritten.
    #
    # @todo   [#247] Clean the headers of only the pods to install.
    #
    def clean_sandbox
      sandbox.public_headers.implode!
      pod_targets.each do |pod_target|
        pod_target.build_headers.implode!
      end

      unless sandbox_state.deleted.empty?
        title_options = { :verbose_prefix => '-> '.red }
        sandbox_state.deleted.each do |pod_name|
          UI.titled_section("Removing #{pod_name}".red, title_options) do
            sandbox.clean_pod(pod_name)
          end
        end
      end
    end

    # TODO: the file accessor should be initialized by the sandbox as they
    #       created by the Pod source installer as well.
    #
    def create_file_accessors
      aggregate_targets.each do |target|
        target.pod_targets.each do |pod_target|
          pod_root = sandbox.pod_dir(pod_target.root_spec.name)
          path_list = Sandbox::PathList.new(pod_root)
          file_accessors = pod_target.specs.map do |spec|
            Sandbox::FileAccessor.new(path_list, spec.consumer(pod_target.platform))
          end
          pod_target.file_accessors ||= []
          pod_target.file_accessors.concat(file_accessors)
        end
      end
    end

    # Downloads, installs the documentation and cleans the sources of the Pods
    # which need to be installed.
    #
    # @return [void]
    #
    def install_pod_sources
      @installed_specs = []
      pods_to_install = sandbox_state.added | sandbox_state.changed
      title_options = { :verbose_prefix => '-> '.green }
      root_specs.sort_by(&:name).each do |spec|
        if pods_to_install.include?(spec.name)
          if sandbox_state.changed.include?(spec.name) && sandbox.manifest
            previous = sandbox.manifest.version(spec.name)
            title = "Installing #{spec.name} #{spec.version} (was #{previous})"
          else
            title = "Installing #{spec}"
          end
          UI.titled_section(title.green, title_options) do
            install_source_of_pod(spec.name)
          end
        else
          UI.titled_section("Using #{spec}", title_options)
        end
      end
    end

    # Install the Pods. If the resolver indicated that a Pod should be
    # installed and it exits, it is removed an then reinstalled. In any case if
    # the Pod doesn't exits it is installed.
    #
    # @return [void]
    #
    def install_source_of_pod(pod_name)
      specs_by_platform = {}
      pod_targets.each do |pod_target|
        if pod_target.root_spec.name == pod_name
          specs_by_platform[pod_target.platform] ||= []
          specs_by_platform[pod_target.platform].concat(pod_target.specs)
        end
      end

      @pod_installers ||= []
      pod_installer = PodSourceInstaller.new(sandbox, specs_by_platform)
      pod_installer.install!
      @pod_installers << pod_installer
      @installed_specs.concat(specs_by_platform.values.flatten.uniq)
    end

    # Cleans the sources of the Pods if the config instructs to do so.
    #
    # @todo Why the @pod_installers might be empty?
    #
    def clean_pod_sources
      return unless config.clean?
      return unless @pod_installers
      @pod_installers.each(&:clean!)
    end

    # Performs any post-installation actions
    #
    # @return [void]
    #
    def perform_post_install_actions
      run_plugins_post_install_hooks
      warn_for_deprecations
    end

    # Runs the registered callbacks for the plugins post install hooks.
    #
    def run_plugins_post_install_hooks
      context = HooksContext.generate(sandbox, aggregate_targets)
      HooksManager.run(:post_install, context)
    end

    # Prints a warning for any pods that are deprecated
    #
    # @return [void]
    #
    def warn_for_deprecations
      deprecated_pods = root_specs.select do |spec|
        spec.deprecated || spec.deprecated_in_favor_of
      end
      deprecated_pods.each do |spec|
        if spec.deprecated_in_favor_of
          UI.warn "#{spec.name} has been deprecated in " \
            "favor of #{spec.deprecated_in_favor_of}"
        else
          UI.warn "#{spec.name} has been deprecated"
        end
      end
    end

    # Creates the Pods project from scratch if it doesn't exists.
    #
    # @return [void]
    #
    # @todo   Clean and modify the project if it exists.
    #
    def prepare_pods_project
      UI.message '- Creating Pods project' do
        @pods_project = Pod::Project.new(sandbox.project_path)

        analysis_result.all_user_build_configurations.each do |name, type|
          @pods_project.add_build_configuration(name, type)
        end

        pod_names = pod_targets.map(&:pod_name).uniq
        pod_names.each do |pod_name|
          local = sandbox.local?(pod_name)
          path = sandbox.pod_dir(pod_name)
          was_absolute = sandbox.local_path_was_absolute?(pod_name)
          @pods_project.add_pod_group(pod_name, path, local, was_absolute)
        end

        if config.podfile_path
          @pods_project.add_podfile(config.podfile_path)
        end

        sandbox.project = @pods_project
        platforms = aggregate_targets.map(&:platform)
        osx_deployment_target = platforms.select { |p| p.name == :osx }.map(&:deployment_target).min
        ios_deployment_target = platforms.select { |p| p.name == :ios }.map(&:deployment_target).min
        @pods_project.build_configurations.each do |build_configuration|
          build_configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = osx_deployment_target.to_s if osx_deployment_target
          build_configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = ios_deployment_target.to_s if ios_deployment_target
          build_configuration.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
          build_configuration.build_settings['CLANG_ENABLE_OBJC_ARC'] = 'YES'
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
      installer = FileReferencesInstaller.new(sandbox, pod_targets, pods_project)
      installer.install!
    end

    # Installs the aggregate targets of the Pods projects and generates their
    # support files.
    #
    # @return [void]
    #
    def install_libraries
      UI.message '- Installing targets' do
        pod_targets.sort_by(&:name).each do |pod_target|
          next if pod_target.target_definition.dependencies.empty?
          target_installer = PodTargetInstaller.new(sandbox, pod_target)
          target_installer.install!
        end

        aggregate_targets.sort_by(&:name).each do |target|
          next if target.target_definition.dependencies.empty?
          target_installer = AggregateTargetInstaller.new(sandbox, target)
          target_installer.install!
        end

        # TODO
        # Move and add specs
        pod_targets.sort_by(&:name).each do |pod_target|
          pod_target.file_accessors.each do |file_accessor|
            file_accessor.spec_consumer.frameworks.each do |framework|
              pod_target.native_target.add_system_framework(framework)
            end
          end
        end
      end
    end

    def set_target_dependencies
      aggregate_targets.each do |aggregate_target|
        aggregate_target.pod_targets.each do |pod_target|
          aggregate_target.native_target.add_dependency(pod_target.native_target)
          pod_target.dependencies.each do |dep|

            unless dep == pod_target.pod_name
              pod_dependency_target = aggregate_target.pod_targets.find { |target| target.pod_name == dep }
              # TODO remove me
              unless pod_dependency_target
                puts "[BUG] DEP: #{dep}"
              end
              pod_target.native_target.add_dependency(pod_dependency_target.native_target)
            end
          end
        end
      end
    end

    # Writes the Pods project to the disk.
    #
    # @return [void]
    #
    def write_pod_project
      UI.message "- Writing Xcode project file to #{UI.path sandbox.project_path}" do
        pods_project.pods.remove_from_project if pods_project.pods.empty?
        pods_project.development_pods.remove_from_project if pods_project.development_pods.empty?
        pods_project.sort(:groups_position => :below)
        pods_project.recreate_user_schemes(false)
        pods_project.save
      end
    end

    # Writes the Podfile and the lock files.
    #
    # @todo   Pass the checkout options to the Lockfile.
    #
    # @return [void]
    #
    def write_lockfiles
      external_source_pods = podfile.dependencies.select(&:external_source).map(&:root_name).uniq
      checkout_options = sandbox.checkout_sources.select { |root_name, _| external_source_pods.include? root_name }
      @lockfile = Lockfile.generate(podfile, analysis_result.specifications, checkout_options)

      UI.message "- Writing Lockfile in #{UI.path config.lockfile_path}" do
        @lockfile.write_to_disk(config.lockfile_path)
      end

      UI.message "- Writing Manifest in #{UI.path sandbox.manifest_path}" do
        @lockfile.write_to_disk(sandbox.manifest_path)
      end
    end

    # Integrates the user projects adding the dependencies on the CocoaPods
    # libraries, setting them up to use the xcconfigs and performing other
    # actions. This step is also responsible of creating the workspace if
    # needed.
    #
    # @return [void]
    #
    # @todo   [#397] The libraries should be cleaned and the re-added on every
    #         installation. Maybe a clean_user_project phase should be added.
    #         In any case it appears to be a good idea store target definition
    #         information in the lockfile.
    #
    def integrate_user_project
      UI.section "Integrating client #{'project'.pluralize(aggregate_targets.map(&:user_project_path).uniq.count) }" do
        installation_root = config.installation_root
        integrator = UserProjectIntegrator.new(podfile, sandbox, installation_root, aggregate_targets)
        integrator.integrate!
      end
    end

    #-------------------------------------------------------------------------#

    private

    # @!group Hooks

    # Runs the pre install hooks of the installed specs and of the Podfile.
    #
    # @return [void]
    #
    def run_pre_install_hooks
      UI.message '- Running pre install hooks' do
        executed = run_podfile_pre_install_hook
        UI.message '- Podfile' if executed
      end
    end

    # Runs the pre install hook of the Podfile
    #
    # @raise  Raises an informative if the hooks raises.
    #
    # @return [Bool] Whether the hook was run.
    #
    def run_podfile_pre_install_hook
      podfile.pre_install!(installer_rep)
    rescue => e
      raise Informative, 'An error occurred while processing the pre-install ' \
        'hook of the Podfile.' \
        "\n\n#{e.message}\n\n#{e.backtrace * "\n"}"
    end

    # Runs the post install hooks of the installed specs and of the Podfile.
    #
    # @note   Post install hooks run _before_ saving of project, so that they
    #         can alter it before it is written to the disk.
    #
    # @return [void]
    #
    def run_podfile_post_install_hooks
      UI.message '- Running post install hooks' do
        executed = run_podfile_post_install_hook
        UI.message '- Podfile' if executed
      end
    end

    # Runs the post install hook of the Podfile
    #
    # @raise  Raises an informative if the hooks raises.
    #
    # @return [Bool] Whether the hook was run.
    #
    def run_podfile_post_install_hook
      podfile.post_install!(installer_rep)
    rescue => e
      raise Informative, 'An error occurred while processing the post-install ' \
        'hook of the Podfile.' \
        "\n\n#{e.message}\n\n#{e.backtrace * "\n"}"
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Hooks Data

    # @return [InstallerRepresentation]
    #
    def installer_rep
      Hooks::InstallerRepresentation.new(self)
    end

    # @return [PodRepresentation] The hook representation of a Pod.
    #
    # @param  [String] pod
    #         The name of the pod.
    #
    # @return [PodRepresentation] The pod representation.
    #
    def pod_rep(pod)
      all_file_accessors = pod_targets.map(&:file_accessors).flatten.compact
      file_accessors = all_file_accessors.select { |fa| fa.spec.root.name == pod }
      Hooks::PodRepresentation.new(pod, file_accessors)
    end

    # @return [LibraryRepresentation]
    #
    def library_rep(aggregate_target)
      Hooks::LibraryRepresentation.new(sandbox, aggregate_target)
    end

    # @return [Array<LibraryRepresentation>]
    #
    def library_reps
      @library_reps ||= aggregate_targets.map { |lib| library_rep(lib) }
    end

    # @return [Array<PodRepresentation>]
    #
    def pod_reps
      root_specs.sort_by(&:name).map { |spec| pod_rep(spec.name) }
    end

    # Returns the libraries which use the given specification.
    #
    # @param  [Specification] spec
    #         The specification for which the client libraries are needed.
    #
    # @return [Array<Library>] The library.
    #
    def libraries_using_spec(spec)
      aggregate_targets.select do |aggregate_target|
        aggregate_target.pod_targets.any? { |pod_target| pod_target.specs.include?(spec) }
      end
    end

    # @return [Array<Library>] The libraries generated by the installation
    #         process.
    #
    def pod_targets
      aggregate_targets.map(&:pod_targets).flatten
    end

    #-------------------------------------------------------------------------#

    private

    # @!group Private helpers

    # @return [Array<Specification>] All the root specifications of the
    #         installation.
    #
    def root_specs
      analysis_result.specifications.map(&:root).uniq
    end

    # @return [SpecsState] The state of the sandbox returned by the analyzer.
    #
    def sandbox_state
      analysis_result.sandbox_state
    end

    #-------------------------------------------------------------------------#
  end
end
