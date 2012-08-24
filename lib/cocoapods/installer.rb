require 'colored'

module Pod
  class Installer
    autoload :TargetInstaller,       'cocoapods/installer/target_installer'
    autoload :UserProjectIntegrator, 'cocoapods/installer/user_project_integrator'

    include Config::Mixin

    attr_reader :resolver, :sandbox, :lockfile

    def initialize(resolver)
      @resolver = resolver
      @podfile = resolver.podfile
      @sandbox = resolver.sandbox
    end

    def project
      return @project if @project
      @project = Pod::Project.new
      @project.user_build_configurations = @podfile.user_build_configurations
      pods.each do |pod|
        # Add all source files to the project grouped by pod
        pod.relative_source_files_by_spec.each do |spec, paths|
          parent_group = pod.local? ? @project.local_pods : @project.pods
          group = @project.add_spec_to_group(pod.name, parent_group)
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

    # Install the Pods. If the resolver indicated that a Pod should be installed
    #   and it exits, it is removed an then reinstalled. In any case if the Pod
    #   doesn't exits it is installed.
    #
    # @return [void]
    #
    def install_dependencies!
      pods.sort_by { |pod| pod.top_specification.name.downcase }.each do |pod|
        name = pod.top_specification.name
        should_install = @resolver.should_install?(name) || !pod.exists?

        unless config.silent?
          marker = config.verbose ? "\n-> ".green : ''
          if subspec_name = pod.top_specification.preferred_dependency
            name = "#{pod.top_specification.name}/#{subspec_name} (#{pod.top_specification.version})"
          else
            name = pod.to_s
          end
          puts marker << ( should_install ? "Installing #{name}".green : "Using #{name}" )
        end

        if should_install
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
      end
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
        puts "-> Installing documentation" if config.verbose?
        doc_generator.generate(config.doc_install?)
      else
        puts "-> Using existing documentation" if config.verbose?
      end
    end

    # @TODO: use the local pod implode
    #
    def remove_deleted_dependencies!
      resolver.removed_pods.each do |pod_name|
        marker = config.verbose ? "\n-> ".red : ''
        path = sandbox.root + pod_name
        puts marker << "Removing #{pod_name}".red
        path.rmtree if path.exist?
      end
    end

    def install!
      @sandbox.prepare_for_install

      print_title "Resolving dependencies of: #{@podfile.defined_in_file}"
      specs_by_target

      print_title "Removing deleted dependencies" unless resolver.removed_pods.empty?
      remove_deleted_dependencies!

      print_title "Installing dependencies"
      install_dependencies!

      print_title("Generating support files\n", false)
      target_installers.each do |target_installer|
        pods_for_target = pods_by_target[target_installer.target_definition]
        target_installer.install!(pods_for_target, @sandbox)
        acknowledgements_path = target_installer.target_definition.acknowledgements_path
        Generator::Acknowledgements.new(target_installer.target_definition,
                                        pods_for_target).save_as(acknowledgements_path)
        generate_dummy_source(target_installer)
      end

      puts "- Running post install hooks" if config.verbose?
      # Post install hooks run _before_ saving of project, so that they can alter it before saving.
      run_post_install_hooks

      puts "- Writing Xcode project file to `#{@sandbox.project_path}'" if config.verbose?
      project.save_as(@sandbox.project_path)

      puts "- Writing lockfile in `#{config.project_lockfile}'\n\n" if config.verbose?
      @lockfile = Lockfile.generate(@podfile, specs_by_target.values.flatten)
      @lockfile.write_to_disk(config.project_lockfile)

      UserProjectIntegrator.new(@podfile).integrate! if config.integrate_targets?
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

    def specs_by_target
      @specs_by_target ||= @resolver.resolve
    end

    # @return [Array<Specification>]  All dependencies that have been resolved.
    def specifications
      specs_by_target.values.flatten
    end

    # @return [Array<LocalPod>]  A list of LocalPod instances for each
    #                            dependency that is not a download-only one.
    def pods
      pods_by_target.values.flatten
    end

    def pods_by_target
      @pods_by_spec = {}
      result = {}
      specs_by_target.each do |target_definition, specs|
        @pods_by_spec[target_definition.platform] = {}
        result[target_definition] = specs.map do |spec|
          if spec.local?
            LocalPod::LocalSourcedPod.new(spec, sandbox, target_definition.platform)
          else
            @sandbox.local_pod_for_spec(spec, target_definition.platform)
          end
        end.uniq.compact
      end
      result
    end

    private

    def print_title(title, only_verbose = true)
      if config.verbose?
        puts "\n" + title.yellow
      elsif !config.silent? && !only_verbose
        puts title
      end
    end
  end
end
