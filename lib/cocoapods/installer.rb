require 'active_support/core_ext/string/inflections'
require 'fileutils'

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
    autoload :Analyzer,                   'cocoapods/installer/analyzer'
    autoload :InstallationOptions,        'cocoapods/installer/installation_options'
    autoload :PostInstallHooksContext,    'cocoapods/installer/post_install_hooks_context'
    autoload :PreInstallHooksContext,     'cocoapods/installer/pre_install_hooks_context'
    autoload :SourceProviderHooksContext, 'cocoapods/installer/source_provider_hooks_context'
    autoload :PodfileValidator,           'cocoapods/installer/podfile_validator'
    autoload :PodSourceInstaller,         'cocoapods/installer/pod_source_installer'
    autoload :PodSourcePreparer,          'cocoapods/installer/pod_source_preparer'
    autoload :UserProjectIntegrator,      'cocoapods/installer/user_project_integrator'
    autoload :Xcode,                      'cocoapods/installer/xcode'

    include Config::Mixin
    include InstallationOptions::Mixin

    delegate_installation_options { podfile }

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

    # Initialize a new instance
    #
    # @param  [Sandbox]  sandbox     @see sandbox
    # @param  [Podfile]  podfile     @see podfile
    # @param  [Lockfile] lockfile    @see lockfile
    #
    def initialize(sandbox, podfile, lockfile = nil)
      @sandbox  = sandbox
      @podfile  = podfile
      @lockfile = lockfile

      @use_default_plugins = true
      @has_dependencies = true
    end

    # @return [Hash, Boolean, nil] Pods that have been requested to be
    #         updated or true if all Pods should be updated.
    #         If all Pods should been updated the contents of the Lockfile are
    #         not taken into account for deciding what Pods to install.
    #
    attr_accessor :update

    # @return [Boolean] Whether it has dependencies. Defaults to true.
    #
    attr_accessor :has_dependencies
    alias_method :has_dependencies?, :has_dependencies

    # @return [Boolean] Whether the spec repos should be updated.
    #
    attr_accessor :repo_update
    alias_method :repo_update?, :repo_update

    # @return [Boolean] Whether default plugins should be used during
    #                   installation. Defaults to true.
    #
    attr_accessor :use_default_plugins
    alias_method :use_default_plugins?, :use_default_plugins

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
      validate_targets
      generate_pods_project
      if installation_options.integrate_targets?
        integrate_user_project
      else
        UI.section 'Skipping User Project Integration'
      end
      perform_post_install_actions
    end

    def prepare
      # Raise if pwd is inside Pods
      if Dir.pwd.start_with?(sandbox.root.to_path)
        message = 'Command should be run from a directory outside Pods directory.'
        message << "\n\n\tCurrent directory is #{UI.path(Pathname.pwd)}\n"
        raise Informative, message
      end
      UI.message 'Preparing' do
        deintegrate_if_different_major_version
        sandbox.prepare
        ensure_plugins_are_installed!
        run_plugins_pre_install_hooks
      end
    end

    # @return [Analyzer] The analyzer used to resolve dependencies
    #
    def resolve_dependencies
      plugin_sources = run_source_provider_hooks
      analyzer = create_analyzer(plugin_sources)

      UI.section 'Updating local specs repositories' do
        analyzer.update_repositories
      end if repo_update?

      UI.section 'Analyzing dependencies' do
        analyze(analyzer)
        validate_build_configurations
        clean_sandbox
      end
      analyzer
    end

    def download_dependencies
      UI.section 'Downloading dependencies' do
        create_file_accessors
        install_pod_sources
        run_podfile_pre_install_hooks
        clean_pod_sources
      end
    end

    #-------------------------------------------------------------------------#

    # @!group Pods Project Generation

    private

    def create_generator
      Xcode::PodsProjectGenerator.new(aggregate_targets, sandbox, pod_targets, analysis_result, installation_options, config)
    end

    # Generate the 'Pods/Pods.xcodeproj' project.
    #
    def generate_pods_project(generator = create_generator)
      UI.section 'Generating Pods project' do
        generator.generate!
        @pods_project = generator.project
        run_podfile_post_install_hooks
        generator.write
        generator.share_development_pod_schemes
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

    # @return [Array<AggregateTarget>] The model representations of an
    #         aggregation of pod targets generated for a target definition
    #         in the Podfile as result of the analyzer.
    #
    attr_reader :aggregate_targets

    # @return [Array<PodTarget>] The model representations of pod targets
    #         generated as result of the analyzer.
    #
    def pod_targets
      aggregate_target_pod_targets = aggregate_targets.flat_map(&:pod_targets)
      test_dependent_targets = aggregate_target_pod_targets.flat_map(&:test_dependent_targets)
      (aggregate_target_pod_targets + test_dependent_targets).uniq
    end

    # @return [Array<Specification>] The specifications that where installed.
    #
    attr_accessor :installed_specs

    #-------------------------------------------------------------------------#

    private

    # @!group Installation steps

    # Performs the analysis.
    #
    # @return [void]
    #
    def analyze(analyzer = create_analyzer)
      analyzer.update = update
      @analysis_result = analyzer.analyze
      @aggregate_targets = analyzer.result.targets
    end

    def create_analyzer(plugin_sources = nil)
      Analyzer.new(sandbox, podfile, lockfile, plugin_sources).tap do |analyzer|
        analyzer.installation_options = installation_options
        analyzer.has_dependencies = has_dependencies?
      end
    end

    # Ensures that the white-listed build configurations are known to prevent
    # silent typos.
    #
    # @raise  If an unknown user configuration is found.
    #
    def validate_build_configurations
      whitelisted_configs = pod_targets.
        flat_map(&:target_definitions).
        flat_map(&:all_whitelisted_configurations).
        map(&:downcase).
        uniq
      all_user_configurations = analysis_result.all_user_build_configurations.keys.map(&:downcase)

      remainder = whitelisted_configs - all_user_configurations
      unless remainder.empty?
        raise Informative,
              "Unknown #{'configuration'.pluralize(remainder.size)} whitelisted: #{remainder.sort.to_sentence}. " \
              "CocoaPods found #{all_user_configurations.sort.to_sentence}, did you mean one of these?"
      end
    end

    # @return [void] In this step we clean all the folders that will be
    #         regenerated from scratch and any file which might not be
    #         overwritten.
    #
    # @todo   [#247] Clean the headers of only the pods to install.
    #
    def clean_sandbox
      sandbox.public_headers.implode!
      target_support_dirs = sandbox.target_support_files_root.children.select(&:directory?)
      pod_targets.each do |pod_target|
        pod_target.build_headers.implode!
        target_support_dirs.delete(pod_target.support_files_dir)
      end

      aggregate_targets.each do |aggregate_target|
        target_support_dirs.delete(aggregate_target.support_files_dir)
      end

      target_support_dirs.each { |dir| FileUtils.rm_rf(dir) }

      unless sandbox_state.deleted.empty?
        title_options = { :verbose_prefix => '-> '.red }
        sandbox_state.deleted.each do |pod_name|
          UI.titled_section("Removing #{pod_name}".red, title_options) do
            sandbox.clean_pod(pod_name)
          end
        end
      end
    end

    # @return [void] In this step we create the file accessors for the pod
    #                targets.
    #
    def create_file_accessors
      sandbox.create_file_accessors(pod_targets)
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
            current_version = spec.version
            previous_version = sandbox.manifest.version(spec.name)
            has_changed_version = current_version != previous_version
            current_repo = analysis_result.specs_by_source.detect { |key, values| break key if values.map(&:name).include?(spec.name) }
            current_repo &&= current_repo.url || current_repo.name
            previous_spec_repo = sandbox.manifest.spec_repo(spec.name)
            has_changed_repo = !previous_spec_repo.nil? && current_repo && (current_repo != previous_spec_repo)
            title = "Installing #{spec.name} #{spec.version}"
            title << " (was #{previous_version} and source changed to `#{current_repo}` from `#{previous_spec_repo}`)" if has_changed_version && has_changed_repo
            title << " (was #{previous_version})" if has_changed_version && !has_changed_repo
            title << " (source changed to `#{current_repo}` from `#{previous_spec_repo}`)" if !has_changed_version && has_changed_repo
          else
            title = "Installing #{spec}"
          end
          UI.titled_section(title.green, title_options) do
            install_source_of_pod(spec.name)
          end
        else
          UI.titled_section("Using #{spec}", title_options) do
            create_pod_installer(spec.name)
          end
        end
      end
    end

    def create_pod_installer(pod_name)
      specs_by_platform = {}
      pod_targets.each do |pod_target|
        if pod_target.root_spec.name == pod_name
          specs_by_platform[pod_target.platform] ||= []
          specs_by_platform[pod_target.platform].concat(pod_target.specs)
        end
      end

      raise Informative, "Could not install '#{pod_name}' pod. There is no target that supports it." if specs_by_platform.empty?

      @pod_installers ||= []
      pod_installer = PodSourceInstaller.new(sandbox, specs_by_platform, :can_cache => installation_options.clean?)
      @pod_installers << pod_installer
      pod_installer
    end

    # Install the Pods. If the resolver indicated that a Pod should be
    # installed and it exits, it is removed and then reinstalled. In any case if
    # the Pod doesn't exits it is installed.
    #
    # @return [void]
    #
    def install_source_of_pod(pod_name)
      pod_installer = create_pod_installer(pod_name)
      pod_installer.install!
      @installed_specs.concat(pod_installer.specs_by_platform.values.flatten.uniq)
    end

    # Cleans the sources of the Pods if the config instructs to do so.
    #
    # @todo Why the @pod_installers might be empty?
    #
    def clean_pod_sources
      return unless installation_options.clean?
      return unless @pod_installers
      @pod_installers.each(&:clean!)
    end

    # Unlocks the sources of the Pods.
    #
    # @todo Why the @pod_installers might be empty?
    #
    def unlock_pod_sources
      return unless @pod_installers
      @pod_installers.each do |installer|
        pod_target = pod_targets.find { |target| target.pod_name == installer.name }
        installer.unlock_files!(pod_target.file_accessors)
      end
    end

    # Locks the sources of the Pods if the config instructs to do so.
    #
    # @todo Why the @pod_installers might be empty?
    #
    def lock_pod_sources
      return unless installation_options.lock_pod_sources?
      return unless @pod_installers
      @pod_installers.each do |installer|
        pod_target = pod_targets.find { |target| target.pod_name == installer.name }
        installer.lock_files!(pod_target.file_accessors)
      end
    end

    def validate_targets
      validator = Xcode::TargetValidator.new(aggregate_targets, pod_targets)
      validator.validate!
    end

    # Runs the registered callbacks for the plugins pre install hooks.
    #
    # @return [void]
    #
    def run_plugins_pre_install_hooks
      context = PreInstallHooksContext.generate(sandbox, podfile, lockfile)
      HooksManager.run(:pre_install, context, plugins)
    end

    # Performs any post-installation actions
    #
    # @return [void]
    #
    def perform_post_install_actions
      unlock_pod_sources
      run_plugins_post_install_hooks
      warn_for_deprecations
      warn_for_installed_script_phases
      lock_pod_sources
      print_post_install_message
    end

    def print_post_install_message
      podfile_dependencies = analysis_result.podfile_dependency_cache.podfile_dependencies.size
      pods_installed = root_specs.size
      title_options = { :verbose_prefix => '-> '.green }
      UI.titled_section('Pod installation complete! ' \
                        "There #{podfile_dependencies == 1 ? 'is' : 'are'} #{podfile_dependencies} " \
                        "#{'dependency'.pluralize(podfile_dependencies)} from the Podfile " \
                        "and #{pods_installed} total #{'pod'.pluralize(pods_installed)} installed.".green,
                        title_options)
    end

    # Runs the registered callbacks for the plugins post install hooks.
    #
    def run_plugins_post_install_hooks
      context = PostInstallHooksContext.generate(sandbox, aggregate_targets)
      HooksManager.run(:post_install, context, plugins)
    end

    # Runs the registered callbacks for the source provider plugin hooks.
    #
    # @return [void]
    #
    def run_source_provider_hooks
      context = SourceProviderHooksContext.generate
      HooksManager.run(:source_provider, context, plugins)
      context.sources
    end

    # Run the deintegrator against all projects in the installation root if the
    # current CocoaPods major version part is different than the one in the
    # lockfile.
    #
    # @return [void]
    #
    def deintegrate_if_different_major_version
      return unless lockfile
      return if lockfile.cocoapods_version.major == Version.create(VERSION).major
      UI.section('Re-creating CocoaPods due to major version update.') do
        projects = Pathname.glob(config.installation_root + '*.xcodeproj').map { |path| Xcodeproj::Project.open(path) }
        deintegrator = Deintegrator.new
        projects.each do |project|
          config.with_changes(:silent => true) { deintegrator.deintegrate_project(project) }
          project.save if project.dirty?
        end
      end
    end

    # Ensures that all plugins specified in the {#podfile} are loaded.
    #
    # @return [void]
    #
    def ensure_plugins_are_installed!
      require 'claide/command/plugin_manager'

      loaded_plugins = Command::PluginManager.specifications.map(&:name)

      podfile.plugins.keys.each do |plugin|
        unless loaded_plugins.include? plugin
          raise Informative, "Your Podfile requires that the plugin `#{plugin}` be installed. Please install it and try installation again."
        end
      end
    end

    DEFAULT_PLUGINS = { 'cocoapods-stats' => {} }

    # Returns the plugins that should be run, as indicated by the default
    # plugins and the podfile's plugins
    #
    # @return [Hash<String, Hash>] The plugins to be used
    #
    def plugins
      if use_default_plugins?
        DEFAULT_PLUGINS.merge(podfile.plugins)
      else
        podfile.plugins
      end
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

    # Prints a warning for any pods that included script phases
    #
    # @return [void]
    #
    def warn_for_installed_script_phases
      pods_to_install = sandbox_state.added | sandbox_state.changed
      pod_targets.group_by(&:pod_name).each do |name, pod_targets|
        if pods_to_install.include?(name)
          script_phase_count = pod_targets.inject(0) { |sum, target| sum + target.script_phases.count }
          unless script_phase_count.zero?
            UI.warn "#{name} has added #{script_phase_count} #{'script phase'.pluralize(script_phase_count)}. " \
              'Please inspect before executing a build. See `https://guides.cocoapods.org/syntax/podspec.html#script_phases` for more information.'
          end
        end
      end
    end

    # Writes the Podfile and the lock files.
    #
    # @todo   Pass the checkout options to the Lockfile.
    #
    # @return [void]
    #
    def write_lockfiles
      external_source_pods = analysis_result.podfile_dependency_cache.podfile_dependencies.select(&:external_source).map(&:root_name).uniq
      checkout_options = sandbox.checkout_sources.select { |root_name, _| external_source_pods.include? root_name }
      @lockfile = Lockfile.generate(podfile, analysis_result.specifications, checkout_options, analysis_result.specs_by_source)

      UI.message "- Writing Lockfile in #{UI.path config.lockfile_path}" do
        @lockfile.write_to_disk(config.lockfile_path)
      end

      UI.message "- Writing Manifest in #{UI.path sandbox.manifest_path}" do
        sandbox.manifest_path.open('w') do |f|
          f.write config.lockfile_path.read
        end
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
      UI.section "Integrating client #{'project'.pluralize(aggregate_targets.map(&:user_project_path).uniq.count)}" do
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
    def run_podfile_pre_install_hooks
      UI.message '- Running pre install hooks' do
        executed = run_podfile_pre_install_hook
        UI.message '- Podfile' if executed
      end
    end

    # Runs the pre install hook of the Podfile
    #
    # @raise  Raises an informative if the hooks raises.
    #
    # @return [Boolean] Whether the hook was run.
    #
    def run_podfile_pre_install_hook
      podfile.pre_install!(self)
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
    # @return [Boolean] Whether the hook was run.
    #
    def run_podfile_post_install_hook
      podfile.post_install!(self)
    rescue => e
      raise Informative, 'An error occurred while processing the post-install ' \
        'hook of the Podfile.' \
        "\n\n#{e.message}\n\n#{e.backtrace * "\n"}"
    end

    #-------------------------------------------------------------------------#

    public

    # @return [Array<PodTarget>] The targets of the development pods generated by
    #         the installation process. This can be used as a convenience method for external scripts.
    #
    def development_pod_targets
      pod_targets.select do |pod_target|
        sandbox.local?(pod_target.pod_name)
      end
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
