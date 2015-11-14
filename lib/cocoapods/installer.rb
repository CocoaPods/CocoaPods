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
    autoload :AggregateTargetInstaller,   'cocoapods/installer/target_installer/aggregate_target_installer'
    autoload :Analyzer,                   'cocoapods/installer/analyzer'
    autoload :FileReferencesInstaller,    'cocoapods/installer/file_references_installer'
    autoload :PostInstallHooksContext,    'cocoapods/installer/post_install_hooks_context'
    autoload :PreInstallHooksContext,     'cocoapods/installer/pre_install_hooks_context'
    autoload :SourceProviderHooksContext, 'cocoapods/installer/source_provider_hooks_context'
    autoload :Migrator,                   'cocoapods/installer/migrator'
    autoload :PodfileValidator,           'cocoapods/installer/podfile_validator'
    autoload :PodSourceInstaller,         'cocoapods/installer/pod_source_installer'
    autoload :PodSourcePreparer,          'cocoapods/installer/pod_source_preparer'
    autoload :PodTargetInstaller,         'cocoapods/installer/target_installer/pod_target_installer'
    autoload :TargetInstaller,            'cocoapods/installer/target_installer'
    autoload :UserProjectIntegrator,      'cocoapods/installer/user_project_integrator'

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
    end

    # @return [Hash, Boolean, nil] Pods that have been requested to be
    #         updated or true if all Pods should be updated.
    #         If all Pods should been updated the contents of the Lockfile are
    #         not taken into account for deciding what Pods to install.
    #
    attr_accessor :update

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
      determine_dependency_product_types
      verify_no_duplicate_framework_names
      verify_no_static_framework_transitive_dependencies
      verify_framework_usage
      generate_pods_project
      integrate_user_project if config.integrate_targets?
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
        sandbox.prepare
        ensure_plugins_are_installed!
        Migrator.migrate(sandbox)
        run_plugins_pre_install_hooks
      end
    end

    def resolve_dependencies
      analyzer = create_analyzer

      plugin_sources = run_source_provider_hooks
      analyzer.sources.insert(0, *plugin_sources)

      UI.section 'Updating local specs repositories' do
        analyzer.update_repositories
      end unless config.skip_repo_update?

      UI.section 'Analyzing dependencies' do
        analyze(analyzer)
        validate_build_configurations
        clean_sandbox
      end
    end

    def download_dependencies
      UI.section 'Downloading dependencies' do
        create_file_accessors
        install_pod_sources
        run_podfile_pre_install_hooks
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
        share_development_pod_schemes
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
      aggregate_targets.map(&:pod_targets).flatten.uniq
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

    def create_analyzer
      Analyzer.new(sandbox, podfile, lockfile)
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
        raise Informative, "Unknown #{'configuration'.pluralize(remainder.size)} whitelisted: #{remainder.sort.to_sentence}."
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
      pod_targets.each do |pod_target|
        pod_root = sandbox.pod_dir(pod_target.root_spec.name)
        path_list = Sandbox::PathList.new(pod_root)
        file_accessors = pod_target.specs.map do |spec|
          Sandbox::FileAccessor.new(path_list, spec.consumer(pod_target.platform))
        end
        pod_target.file_accessors ||= []
        pod_target.file_accessors.concat(file_accessors)
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

      @pod_installers ||= []
      pod_installer = PodSourceInstaller.new(sandbox, specs_by_platform)
      @pod_installers << pod_installer
      pod_installer
    end

    # Install the Pods. If the resolver indicated that a Pod should be
    # installed and it exits, it is removed an then reinstalled. In any case if
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
      return unless config.clean?
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
      return unless config.lock_pod_source?
      return unless @pod_installers
      @pod_installers.each do |installer|
        pod_target = pod_targets.find { |target| target.pod_name == installer.name }
        installer.lock_files!(pod_target.file_accessors)
      end
    end

    # Determines if the dependencies need to be built as dynamic frameworks or
    # if they can be built as static libraries by checking for the Swift source
    # presence. Therefore it is important that the file accessors of the
    # #pod_targets are created.
    #
    # @return [void]
    #
    def determine_dependency_product_types
      aggregate_targets.each do |aggregate_target|
        aggregate_target.pod_targets.each do |pod_target|
          pod_target.host_requires_frameworks ||= aggregate_target.requires_frameworks?
        end
      end
    end

    def verify_no_duplicate_framework_names
      aggregate_targets.each do |aggregate_target|
        aggregate_target.user_build_configurations.keys.each do |config|
          pod_targets = aggregate_target.pod_targets_for_build_configuration(config)
          vendored_frameworks = pod_targets.flat_map(&:file_accessors).flat_map(&:vendored_frameworks)
          frameworks = vendored_frameworks.map { |fw| fw.basename('.framework') }
          frameworks += pod_targets.select { |pt| pt.should_build? && pt.requires_frameworks? }.map(&:product_module_name)

          duplicates = frameworks.group_by { |f| f }.select { |_, v| v.size > 1 }.keys
          unless duplicates.empty?
            raise Informative, "The '#{aggregate_target.label}' target has " \
              "frameworks with conflicting names: #{duplicates.to_sentence}."
          end
        end
      end
    end

    def verify_no_static_framework_transitive_dependencies
      aggregate_targets.each do |aggregate_target|
        next unless aggregate_target.requires_frameworks?

        aggregate_target.user_build_configurations.keys.each do |config|
          pod_targets = aggregate_target.pod_targets_for_build_configuration(config)

          dependencies = pod_targets.select(&:should_build?).flat_map(&:dependencies)
          dependended_upon_targets = pod_targets.select { |t| dependencies.include?(t.pod_name) && !t.should_build? }

          static_libs = dependended_upon_targets.flat_map(&:file_accessors).flat_map(&:vendored_static_artifacts)
          unless static_libs.empty?
            raise Informative, "The '#{aggregate_target.label}' target has " \
              "transitive dependencies that include static binaries: (#{static_libs.to_sentence})"
          end
        end
      end
    end

    def verify_framework_usage
      aggregate_targets.each do |aggregate_target|
        next if aggregate_target.requires_frameworks?

        aggregate_target.user_build_configurations.keys.each do |config|
          pod_targets = aggregate_target.pod_targets_for_build_configuration(config)

          swift_pods = pod_targets.select(&:uses_swift?)
          unless swift_pods.empty?
            raise Informative, 'Pods written in Swift can only be integrated as frameworks; ' \
              'add `use_frameworks!` to your Podfile or target to opt into using it. ' \
              "The Swift #{swift_pods.size == 1 ? 'Pod being used is' : 'Pods being used are'}: " +
              swift_pods.map(&:name).to_sentence
          end
        end
      end
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
      lock_pod_sources
      print_post_install_message
    end

    def print_post_install_message
      podfile_dependencies = podfile.dependencies.uniq.size
      pods_installed = root_specs.size
      UI.info('Pod installation complete! ' \
              "There #{podfile_dependencies == 1 ? 'is' : 'are'} #{podfile_dependencies} " \
              "#{'dependency'.pluralize(podfile_dependencies)} from the Podfile " \
              "and #{pods_installed} total #{'pod'.pluralize(pods_installed)} installed.")
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

    # Creates the Pods project from scratch if it doesn't exists.
    #
    # @return [void]
    #
    # @todo   Clean and modify the project if it exists.
    #
    def prepare_pods_project
      UI.message '- Creating Pods project' do
        object_version = aggregate_targets.map(&:user_project).compact.map { |p| p.object_version.to_i }.min

        if object_version
          @pods_project = Pod::Project.new(sandbox.project_path, false, object_version)
        else
          @pods_project = Pod::Project.new(sandbox.project_path)
        end

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
        watchos_deployment_target = platforms.select { |p| p.name == :watchos }.map(&:deployment_target).min
        tvos_deployment_target = platforms.select { |p| p.name == :tvos }.map(&:deployment_target).min
        @pods_project.build_configurations.each do |build_configuration|
          build_configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = osx_deployment_target.to_s if osx_deployment_target
          build_configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = ios_deployment_target.to_s if ios_deployment_target
          build_configuration.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = watchos_deployment_target.to_s if watchos_deployment_target
          build_configuration.build_settings['TVOS_DEPLOYMENT_TARGET'] = tvos_deployment_target.to_s if tvos_deployment_target
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
          next if pod_target.target_definitions.flat_map(&:dependencies).empty?
          target_installer = PodTargetInstaller.new(sandbox, pod_target)
          target_installer.install!
        end

        aggregate_targets.sort_by(&:name).each do |target|
          next if target.target_definition.dependencies.empty?
          target_installer = AggregateTargetInstaller.new(sandbox, target)
          target_installer.install!
        end

        # TODO: Move and add specs
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
    end

    # Adds a target dependency for each pod spec to each aggregate target and
    # links the pod targets among each other.
    #
    # @return [void]
    #
    def set_target_dependencies
      frameworks_group = pods_project.frameworks_group
      aggregate_targets.each do |aggregate_target|
        is_app_extension = !(aggregate_target.user_targets.map(&:symbol_type) &
          [:app_extension, :watch_extension, :watch2_extension, :tv_extension]).empty?
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

          pod_target.dependencies.each do |dep|
            unless dep == pod_target.pod_name
              pod_dependency_target = aggregate_target.pod_targets.find { |target| target.pod_name == dep }
              # TODO: remove me
              unless pod_dependency_target
                puts "[BUG] DEP: #{dep}"
              end

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
        if config.deterministic_uuids?
          UI.message('- Generating deterministic UUIDs') { pods_project.predictabilize_uuids }
        end
        pods_project.save
      end
    end

    # Shares schemes of development Pods.
    #
    # @return [void]
    #
    def share_development_pod_schemes
      development_pod_targets.select(&:should_build?).each do |pod_target|
        Xcodeproj::XCScheme.share_scheme(pods_project.path, pod_target.label)
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
    # @return [Bool] Whether the hook was run.
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
    # @return [Bool] Whether the hook was run.
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

    # @return [Array<Library>] The targets of the development pods generated by
    #         the installation process.
    #
    def development_pod_targets
      pod_targets.select do |pod_target|
        sandbox.development_pods.keys.include?(pod_target.pod_name)
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

    # Sets the APPLICATION_EXTENSION_API_ONLY build setting to YES for all
    # configurations of the given target
    #
    def configure_app_extension_api_only_for_target(target)
      target.native_target.build_configurations.each do |config|
        config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      end
    end

    #-------------------------------------------------------------------------#
  end
end
