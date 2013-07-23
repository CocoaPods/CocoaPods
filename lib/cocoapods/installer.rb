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

    autoload :Analyzer,                 'cocoapods/installer/analyzer'
    autoload :FileReferencesInstaller,  'cocoapods/installer/file_references_installer'
    autoload :PodSourceInstaller,       'cocoapods/installer/pod_source_installer'
    autoload :TargetInstaller,          'cocoapods/installer/target_installer'
    autoload :AggregateTargetInstaller, 'cocoapods/installer/target_installer/aggregate_target_installer'
    autoload :PodTargetInstaller,       'cocoapods/installer/target_installer/pod_target_installer'
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
    # @return [void]
    #
    def install!
      resolve_dependencies
      download_dependencies
      generate_pods_project
      integrate_user_project if config.integrate_targets?
    end

    def resolve_dependencies
      UI.section "Analyzing dependencies" do
        analyze
        prepare_for_legacy_compatibility
        clean_sandbox
      end
    end

    def download_dependencies
      UI.section "Downloading dependencies" do
        create_file_accessors
        install_pod_sources
        run_pre_install_hooks
        clean_pod_sources
      end
    end

    def generate_pods_project
      UI.section "Generating Pods project" do
        prepare_pods_project
        install_file_references
        install_libraries
        set_target_dependencies
        link_aggregate_target
        run_post_install_hooks
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
    # @note   The warning about the version of the Lockfile doesn't uses the
    #         `UI.warn` method because it prints the output only at the end
    #         of the installation. At that time CocoaPods could have crashed.
    #
    def analyze
      if lockfile && lockfile.cocoapods_version > Version.new(VERSION)
        STDERR.puts '[!] The version of CocoaPods used to generate the lockfile is '\
          'higher that the one of the current executable. Incompatibility ' \
          'issues might arise.'.yellow
      end

      analyzer = Analyzer.new(sandbox, podfile, lockfile)
      analyzer.update_mode = update_mode
      @analysis_result = analyzer.analyze
      @aggregate_targets = analyzer.result.targets
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
        title_options = { :verbose_prefix => "-> ".red }
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
      title_options = { :verbose_prefix => "-> ".green }
      root_specs.sort_by(&:name).each do |spec|
        if pods_to_install.include?(spec.name)
          UI.titled_section("Installing #{spec}".green, title_options) do
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
      pod_installer.aggressive_cache = config.aggressive_cache?
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
      @pod_installers.each do |pod_installer|
        pod_installer.clean!
      end
    end

    # Creates the Pods project from scratch if it doesn't exists.
    #
    # @return [void]
    #
    # @todo   Clean and modify the project if it exists.
    #
    def prepare_pods_project
      UI.message "- Creating Pods project" do
        @pods_project = Pod::Project.new(sandbox.project_path)
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
      UI.message"- Installing libraries" do
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

    def set_target_dependencies
      aggregate_targets.each do |aggregate_target|
        aggregate_target.pod_targets.each do |pod_target|
          add_dependency(aggregate_target, pod_target)
          pod_target.dependencies.each do |dep|

            unless dep == pod_target.pod_name
              pod_dependency_target = aggregate_target.pod_targets.find { |target| target.pod_name == dep }
              # TODO remove me
              unless pod_dependency_target
                puts "[BUG] DEP: #{dep}"
              end
              add_dependency(pod_target, pod_dependency_target)
            end
          end
        end
      end
    end

    # TODO: tmp - move
    #
    def add_dependency(dependent_target, dependency_target)
      container_proxy = pods_project.new(Xcodeproj::Project::PBXContainerItemProxy)
      container_proxy.container_portal = pods_project.root_object.uuid
      container_proxy.proxy_type = '1'
      container_proxy.remote_global_id_string = dependency_target.target.uuid
      container_proxy.remote_info = dependency_target.target.name

      dependency = pods_project.new(Xcodeproj::Project::PBXTargetDependency)
      dependency.target = dependency_target.target
      dependency.targetProxy = container_proxy

      dependent_target.target.dependencies << dependency
    end


    # Links the aggregate targets with all the dependent libraries.
    #
    # @note   This is run in the integration step to ensure that targets
    #         have been created for all per spec libraries.
    #
    def link_aggregate_target
      aggregate_targets.each do |aggregate_target|
        native_target = pods_project.targets.select { |t| t.name == aggregate_target.name }.first
        products = pods_project.products_group
        aggregate_target.pod_targets.each do |pod_target|
          product = products.files.select { |f| f.path == pod_target.product_name }.first
          native_target.frameworks_build_phase.add_file_reference(product)
        end
      end
    end

    # Writes the Pods project to the disk.
    #
    # @return [void]
    #
    def write_pod_project
      UI.message "- Writing Xcode project file to #{UI.path sandbox.project_path}" do
        pods_project.main_group.sort_by_type!
        pods_project['Frameworks'].sort_by_type!
        pods_project.save_as(sandbox.project_path)
      end
    end

    # Writes the Podfile and the lock files.
    #
    # @todo   Pass the checkout options to the Lockfile.
    #
    # @return [void]
    #
    def write_lockfiles
      # checkout_options = sandbox.checkout_options
      @lockfile = Lockfile.generate(podfile, analysis_result.specifications)

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
      UI.message "- Running pre install hooks" do
        analysis_result.specifications.each do |spec|
          executed = false
          libraries_using_spec(spec).each do |lib|
            lib_representation = library_rep(lib)
            executed ||= run_spec_pre_install_hook(spec, lib_representation)
          end
          UI.message "- #{spec.name}" if executed
        end

        executed = run_podfile_pre_install_hook
        UI.message "- Podfile" if executed
      end
    end

    # Runs the pre install hook of the given specification with the given
    # library representation.
    #
    # @param  [Specification] spec
    #         The spec for which the pre install hook should be run.
    #
    # @param  [Hooks::LibraryRepresentation] lib_representation
    #         The library representation to be passed as an argument to the
    #         hook.
    #
    # @raise  Raises an informative if the hooks raises.
    #
    # @return [Bool] Whether the hook was run.
    #
    def run_spec_pre_install_hook(spec, lib_representation)
      spec.pre_install!(pod_rep(spec.root.name), lib_representation)
    rescue => e
      raise Informative, "An error occurred while processing the pre-install " \
        "hook of #{spec}." \
        "\n\n#{e.message}\n\n#{e.backtrace * "\n"}"
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
      raise Informative, "An error occurred while processing the pre-install " \
        "hook of the Podfile." \
        "\n\n#{e.message}\n\n#{e.backtrace * "\n"}"
    end

    # Runs the post install hooks of the installed specs and of the Podfile.
    #
    # @note   Post install hooks run _before_ saving of project, so that they
    #         can alter it before it is written to the disk.
    #
    # @return [void]
    #
    def run_post_install_hooks
      UI.message "- Running post install hooks" do
        analysis_result.specifications.each do |spec|
          executed = false
          libraries_using_spec(spec).each do |lib|
            lib_representation = library_rep(lib)
            executed ||= run_spec_post_install_hook(spec, lib_representation)
          end
          UI.message "- #{spec.name}" if executed
        end
        executed = run_podfile_post_install_hook
        UI.message "- Podfile" if executed
      end
    end


    # Runs the post install hook of the given specification with the given
    # library representation.
    #
    # @param  [Specification] spec
    #         The spec for which the post install hook should be run.
    #
    # @param  [Hooks::LibraryRepresentation] lib_representation
    #         The library representation to be passed as an argument to the
    #         hook.
    #
    # @raise  Raises an informative if the hooks raises.
    #
    # @return [Bool] Whether the hook was run.
    #
    def run_spec_post_install_hook(spec, lib_representation)
      spec.post_install!(lib_representation)
    rescue => e
      raise Informative, "An error occurred while processing the post-install " \
        "hook of #{spec}." \
        "\n\n#{e.message}\n\n#{e.backtrace * "\n"}"
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
      raise Informative, "An error occurred while processing the post-install " \
        "hook of the Podfile." \
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
      root_specs.sort_by { |spec| spec.name }.map { |spec| pod_rep(spec.name) }
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
      analysis_result.specifications.map { |spec| spec.root }.uniq
    end

    # @return [SpecsState] The state of the sandbox returned by the analyzer.
    #
    def sandbox_state
      analysis_result.sandbox_state
    end

    #-------------------------------------------------------------------------#

  end
end
