module Pod

  # The installer is the core of CocoaPods. This class is responsible of taking
  # a Podfile and transform it in the Pods libraries. This class also
  # integrates the user project so the Pods libraries can be used out of the
  # box.
  #
  class Installer
    autoload :TargetInstaller,       'cocoapods/installer/target_installer'
    autoload :UserProjectIntegrator, 'cocoapods/installer/user_project_integrator'

    include Config::Mixin

    # @return [Resolver] The resolver used by the installer.
    #
    attr_reader :resolver

    # @return [Sandbox]  The sandbox where to install the Pods.
    #
    attr_reader :sandbox

    # @return [Podfile]  The Podfile specification that contains the
    #                    information of the Pods that should be installed.
    #
    attr_reader :podfile

    # @return [Lockfile] The Lockfile that stores the information about the
    #                    installed Pods.
    #
    attr_reader :lockfile

    # TODO: The installer should receive the Podfile, the Lockfile, and the
    # sandbox. It shouldn't get those values from the resolver, but it should
    # create the resolver itself.
    #
    def initialize(resolver)
      @resolver = resolver
      @podfile = resolver.podfile
      @sandbox = resolver.sandbox
    end

    # @return [void] The installation process of CocoaPods is mostly linear
    # with very few minor exceptions:
    #
    # - Pods from external sources might be already downloaded if it is
    #   necessary to retrieve their podspec.
    #
    def install!
      detect_podfile_changes
      perform_global_cleaning
      perform_pod_specific_cleaning
      resolve_dependencies

      # TODO: move to perform_pod_specific_cleaning
      UI.section "Removing deleted dependencies" do
        remove_deleted_dependencies!
      end unless resolver.removed_pods.empty?

      prepare_pods_project
      install_dependencies!
      generate_support_files
      integrate_user_project
    end

    # @!group Detect Podfile changes step

    # @return [Hash{Symbol => Array<Spec>}] The pods grouped by a symbol
    #   indicating the state (added, changed, removed, unchanged) as identified
    #   by the {Lockfile}.
    #
    attr_reader :pods_by_state

    # @return [void] Computes the pods that need to be installed.
    #
    def detect_podfile_changes
      if lockfile
        UI.section "Finding added, modified or removed dependencies:" do
          @pods_by_state = @lockfile.detect_changes_with_podfile(podfile)
          print_pods_states_list
          @unchanged_pods = (lockfile.pods_names - pods_by_state[:added] - pods_by_state[:changed] - pods_by_state[:removed]).uniq
        end
      else
        @pods_by_state  = {}
        @unchanged_pods = []
      end
    end

    # @return [void] Outputs a lists of the pods by state.
    #
    def print_pods_states_list
      return if config.verbose?
      marks = {:added => "A".green, :changed => "M".yellow, :removed => "R".red, :unchanged => "-" }
      pods_by_state.each do |symbol, pod_names|
        pod_names.each do |pod_name|
          UI.message("#{marks[symbol]} #{pod_name}", '',2)
        end
      end
    end

    # @!group Cleaning steps

    def perform_global_cleaning
      @sandbox.prepare_for_install
    end

    def perform_pod_specific_cleaning
      # TODO: clean the headers of only the pods to install
    end

    # Resolves the dependencies with the resolver
    #
    def resolve_dependencies
      #TODO: prepare the resolver
      #TODO: lock the dependencies
      UI.section "Resolving dependencies of #{UI.path @podfile.defined_in_file}" do
        @specs_by_target = @resolver.resolve
      end
    end

    # @return [Hash{Podfile::TargetDefinition => Array<Spec>}]
    #                     The specifications grouped by target as identified in
    #                     the resolve_dependencies step.
    #
    attr_reader :specs_by_target


    def prepare_pods_project

    end

    # Install the Pods. If the resolver indicated that a Pod should be installed
    #   and it exits, it is removed an then reinstalled. In any case if the Pod
    #   doesn't exits it is installed.
    #
    # @return [void]
    #
    def install_dependencies!
      UI.section "Downloading dependencies" do
        pods.sort_by { |pod| pod.top_specification.name.downcase }.each do |pod|
          should_install = @resolver.should_install?(pod.top_specification.name) || !pod.exists?
          if should_install
            UI.section("Installing #{pod}".green, "-> ".green) do
              unless pod.downloaded?
                pod.implode
                download_pod(pod)
              end
              # The docs need to be generated before cleaning because the
              # documentation is created for all the subspecs.
              generate_docs(pod)
              # Here we clean pod's that just have been downloaded or have been
              # pre-downloaded in AbstractExternalSource#specification_from_sandbox.
              pod.clean! if config.clean?
            end
          else
            UI.section("Using #{pod}", "-> ".green)
          end
        end
      end
    end

    def generate_support_files
      UI.section "Generating support files" do
        UI.message "- Running pre install hooks" do
          run_pre_install_hooks
        end

        UI.message"- Installing targets" do
          generate_target_support_files
        end

        UI.message "- Running post install hooks" do
          # Post install hooks run _before_ saving of project, so that they can alter it before saving.
          run_post_install_hooks
        end

        UI.message "- Writing Xcode project file to #{UI.path @sandbox.project_path}" do
          project.save_as(@sandbox.project_path)
        end

        UI.message "- Writing lockfile in #{UI.path config.project_lockfile}" do
          @lockfile = Lockfile.generate(@podfile, specs_by_target.values.flatten)
          @lockfile.write_to_disk(config.project_lockfile)
        end
      end

    end

    def integrate_user_project
        UserProjectIntegrator.new(@podfile).integrate! if config.integrate_targets?
    end

    # @!group Supporting operations

    def project
      return @project if @project
      @project = Pod::Project.new
      @project.user_build_configurations = @podfile.user_build_configurations
      pods.each do |pod|
        # Add all source files to the project grouped by pod
        pod.relative_source_files_by_spec.each do |spec, paths|
          parent_group = pod.local? ? @project.local_pods : @project.pods
          group = @project.add_spec_group(spec.name, parent_group)
          paths.each do |path|
            group.files.new('path' => path.to_s)
          end
        end
      end
      # Add a group to hold all the target support files
      @project.main_group.groups.new('name' => 'Targets Support Files')
      @project
    end

    def target_installers
      @target_installers ||= @podfile.target_definitions.values.map do |definition|
        TargetInstaller.new(@podfile, project, definition) unless definition.empty?
      end.compact
    end



    def download_pod(pod)
      downloader = Downloader.for_pod(pod)
      # Force the `bleeding edge' version if necessary.
      if pod.top_specification.version.head?
        if downloader.respond_to?(:download_head)
          downloader.download_head
        else
          raise Informative, "The downloader of class `#{downloader.class.name}' does not support the `:head' option."
        end
      else
        downloader.download
      end
      pod.downloaded = true
    end

    #TODO: move to generator ?
    def generate_docs(pod)
      doc_generator = Generator::Documentation.new(pod)
      if ( config.generate_docs? && !doc_generator.already_installed? )
        UI.section " > Installing documentation"
        doc_generator.generate(config.doc_install?)
      else
        UI.section " > Using existing documentation"
      end
    end

    # @TODO: use the local pod implode
    #
    def remove_deleted_dependencies!
      resolver.removed_pods.each do |pod_name|
        UI.section("Removing #{pod_name}", "-> ".red) do
          path = sandbox.root + pod_name
          path.rmtree if path.exist?
        end
      end
    end



    def run_pre_install_hooks
      pods_by_target.each do |target_definition, pods|
        pods.each do |pod|
          pod.top_specification.pre_install(pod, target_definition)
        end
      end
      @podfile.pre_install!(self)
    end

    def run_post_install_hooks
      # we loop over target installers instead of pods, because we yield the target installer
      # to the spec post install hook.
      target_installers.each do |target_installer|
        specs_by_target[target_installer.target_definition].each do |spec|
          spec.post_install(target_installer)
        end
      end
      @podfile.post_install!(self)
    end

    def generate_target_support_files
      target_installers.each do |target_installer|
        pods_for_target = pods_by_target[target_installer.target_definition]
        target_installer.install!(pods_for_target, @sandbox)
        acknowledgements_path = target_installer.target_definition.acknowledgements_path
        Generator::Acknowledgements.new(target_installer.target_definition,
                                        pods_for_target).save_as(acknowledgements_path)
        generate_dummy_source(target_installer)
      end
    end

    def generate_dummy_source(target_installer)
      class_name_identifier = target_installer.target_definition.label
      dummy_source = Generator::DummySource.new(class_name_identifier)
      filename = "#{dummy_source.class_name}.m"
      pathname = Pathname.new(sandbox.root + filename)
      dummy_source.save_as(pathname)

      project_file = project.files.new('path' => filename)
      project.group("Targets Support Files") << project_file

      target_installer.target.source_build_phases.first << project_file
    end

    # @return [Array<Specification>]  All dependencies that have been resolved.
    def specifications
      specs_by_target.values.flatten
    end

    # @return [Array<LocalPod>]  A list of LocalPod instances for each
    #                            dependency that is not a download-only one.
    def pods
      pods_by_target.values.flatten.uniq
    end

    def pods_by_target
      @pods_by_spec = {}
      result = {}
      specs_by_target.each do |target_definition, specs|
        @pods_by_spec[target_definition.platform] = {}
        result[target_definition] = specs.map do |spec|
          if spec.local?
            @sandbox.locally_sourced_pod_for_spec(spec, target_definition.platform)
          else
            @sandbox.local_pod_for_spec(spec, target_definition.platform)
          end
        end.uniq.compact
      end
      result
    end
  end
end
