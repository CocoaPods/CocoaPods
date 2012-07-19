require 'colored'

module Pod
  class Installer
    autoload :TargetInstaller,       'cocoapods/installer/target_installer'
    autoload :UserProjectIntegrator, 'cocoapods/installer/user_project_integrator'

    include Config::Mixin

    attr_reader :sandbox

    def initialize(podfile)
      @podfile = podfile
      # FIXME: pass this into the installer as a parameter
      @sandbox = Sandbox.new(config.project_pods_root)
      @resolver = Resolver.new(@podfile, @sandbox)
      # TODO: remove in 0.7 (legacy support for config.ios? and config.osx?)
      config.podfile = podfile
    end

    def lock_file
      config.project_root + 'Podfile.lock'
    end

    def project
      return @project if @project
      @project = Pod::Project.new
      @project.user_build_configurations = @podfile.user_build_configurations
      pods.each do |pod|
        # Add all source files to the project grouped by pod
        group = @project.add_pod_group(pod.name)
        pod.relative_source_files.each do |path|
          group.files.new('path' => path.to_s)
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

    def install_dependencies!
      pods.each do |pod|
        unless config.silent?
          marker = config.verbose ? "\n-> ".green : ''
          if subspec_name = pod.top_specification.preferred_dependency
            name = "#{pod.top_specification.name}/#{subspec_name} (#{pod.top_specification.version})"
          else
            name = pod.to_s
          end
          name << " [HEAD]" if pod.top_specification.version.head?
          puts marker << ( pod.exists? ? "Using #{name}" : "Installing #{name}".green )
        end

        unless pod.exists?
          download_pod(pod)
          # The docs need to be generated before cleaning because
          # the documentation is created for all the subspecs.
          generate_docs(pod)
          pod.clean if config.clean
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

    def install!
      @sandbox.prepare_for_install

      print_title "Resolving dependencies of: #{@podfile.defined_in_file}"
      specs_by_target

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

      generate_lock_file!(specifications)

      puts "- Running post install hooks" if config.verbose?
      # Post install hooks run _before_ saving of project, so that they can alter it before saving.
      run_post_install_hooks

      puts "- Writing Xcode project file to `#{@sandbox.project_path}'\n\n" if config.verbose?
      project.save_as(@sandbox.project_path)

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

    def generate_lock_file!(specs)
      lock_file.open('w') do |file|
        file.puts "PODS:"

        # Get list of [name, dependencies] pairs.
        pod_and_deps = specs.map do |spec|
          [spec.to_s, spec.dependencies.map(&:to_s).sort]
        end.uniq

        # Merge dependencies of ios and osx version of the same pod.
        tmp = {}
        pod_and_deps.each do |name, deps|
          if tmp[name]
            tmp[name].concat(deps).uniq!
          else
            tmp[name] = deps
          end
        end
        pod_and_deps = tmp

        # Sort by name and print
        pod_and_deps.sort_by(&:first).each do |name, deps|
          if deps.empty?
            file.puts "  - #{name}"
          else
            file.puts "  - #{name}:"
            deps.each { |dep| file.puts "    - #{dep}" }
          end
        end

        file.puts
        file.puts "DEPENDENCIES:"
        @podfile.dependencies.map(&:to_s).sort.each do |dep|
          file.puts "  - #{dep}"
        end
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
          pod = pod_for_spec(spec, target_definition.platform)
          pod.add_specification(spec)
          pod
        end.uniq.compact
      end
      result
    end

    def pod_for_spec(spec, platform)
      @pods_by_spec[platform][spec.top_level_parent.name] ||= LocalPod.new(spec, @sandbox, platform)
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
