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
      activated_pods.each do |pod|
        # Add all source files to the project grouped by pod
        group = @project.add_pod_group(pod.name)
        pod.source_files.each do |path|
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
      activated_pods.each do |pod|
        marker = config.verbose ? "\n-> ".green : ''

        unless should_install = !pod.exists? && !pod.specification.local?
          puts marker + "Using #{pod}" unless config.silent?
        else
          puts marker + "Installing #{pod.specification}".green unless config.silent?

          downloader = Downloader.for_pod(pod)
          downloader.download

          if config.clean
            downloader.clean
            pod.clean
          end
        end

        if (should_install && config.generate_docs?) || config.force_doc?
          doc_generator = Generator::Documentation.new(pod)
          if doc_generator.already_installed?
            puts "Using Existing Documentation for #{pod.specification}".green if config.verbose?
          else
            puts "Installing Documentation for #{pod.specification}".green if config.verbose?
            doc_generator.generate(config.doc_install?)
          end
        end
      end
    end

    def install!
      @sandbox.prepare_for_install

      print_title "Resolving dependencies of: #{@podfile.defined_in_file}"
      specs_by_target

      print_title "Installing dependencies"
      install_dependencies!

      pods = activated_pods
      print_title("Generating support files\n", false)
      target_installers.each do |target_installer|
        pods_for_target = activated_pods_by_target[target_installer.target_definition]
        target_installer.install!(pods_for_target, @sandbox)
        acknowledgements_path = config.project_pods_root +
                                "#{target_installer.target_definition.label}-Acknowledgements"
        Generator::Acknowledgements.new(target_installer.target_definition,
                                        pods_for_target).save_as(acknowledgements_path)
      end

      generate_lock_file!(pods)
      generate_dummy_source

      puts "* Running post install hooks" if config.verbose?
      # Post install hooks run _before_ saving of project, so that they can alter it before saving.
      run_post_install_hooks

      puts "* Writing Xcode project file to `#{@sandbox.project_path}'\n\n" if config.verbose?
      project.save_as(@sandbox.project_path)

      UserProjectIntegrator.new(@podfile).integrate! if config.integrate_targets?
    end

    def run_post_install_hooks
      # we loop over target installers instead of pods, because we yield the target installer
      # to the spec post install hook.
      target_installers.each do |target_installer|
        activated_specifications_for_target(target_installer.target_definition).each do |spec|
          spec.post_install(target_installer)
        end
      end

      @podfile.post_install!(self)
    end

    def generate_lock_file!(pods)
      lock_file.open('w') do |file|
        file.puts "PODS:"

        # Get list of [name, dependencies] pairs.
        activated_pods = pods.map do |pod|
          [pod.specification.to_s, pod.dependencies.map(&:to_s).sort]
        end.uniq

        # Merge dependencies of ios and osx version of the same pod.
        tmp = {}
        activated_pods.each do |name, deps|
          if tmp[name]
            tmp[name].concat(deps).uniq!
          else
            tmp[name] = deps
          end
        end
        activated_pods = tmp

        # Sort by name and print
        activated_pods.sort_by(&:first).each do |name, deps|
          if deps.empty?
            file.puts "  - #{name}"
          else
            file.puts "  - #{name}:"
            deps.each { |dep| file.puts "    - #{dep}" }
          end
        end

        unless download_only_specifications.empty?
          file.puts
          file.puts "DOWNLOAD_ONLY:"
          download_only_specifications.map(&:to_s).sort.each do |name|
            file.puts "  - #{name}"
          end
        end

        file.puts
        file.puts "DEPENDENCIES:"
        @podfile.dependencies.map(&:to_s).sort.each do |dep|
          file.puts "  - #{dep}"
        end
      end
    end

    def generate_dummy_source
      filename = "PodsDummy.m"
      pathname = Pathname.new(sandbox.root + filename)
      Generator::DummySource.new.save_as(pathname)

      project_file = project.files.new('path' => filename)
      project.group("Targets Support Files") << project_file

      target_installers.each do |target_installer|
        target_installer.target.source_build_phases.first << project_file
      end
    end

    def specs_by_target
      @specs_by_target ||= @resolver.resolve
    end

    # @return [Array<Specification>]  All dependencies that have been resolved.
    def dependency_specifications
      specs_by_target.values.flatten
    end

    # @return [Array<LocalPod>]  A list of LocalPod instances for each
    #                            dependency that is not a download-only one.
    def activated_pods
      activated_pods_by_target.values.flatten
    end

    def activated_pods_by_target
      result = {}
      specs_by_target.each do |target_definition, specs|
        result[target_definition] = specs.map do |spec|
          LocalPod.new(spec, @sandbox, target_definition.platform) if activated_spec?(spec)
        end.compact
      end
      result
    end

    # @return [Array<Specification>]  A list of specifications for each
    #                                 dependency that is not a download-only
    #                                 one.
    def activated_specifications
      dependency_specifications.select { |spec| activated_spec?(spec) }
    end

    def activated_specifications_for_target(target_definition)
      specs_by_target[target_definition].select { |spec| activated_spec?(spec) }
    end

    def download_only_specifications
      dependency_specifications - activated_specifications
    end

    private

    def activated_spec?(spec)
      # Don't activate specs which are only wrappers of subspecs, or share
      # source with another pod but aren't activated themselves.
      !spec.wrapper? && !@resolver.cached_sets[spec.name].only_part_of_other_pod?
    end

    def print_title(title, only_verbose = true)
      if config.verbose?
        puts "\n" + title.yellow
      elsif !config.silent? && !only_verbose
        puts title
      end
    end
  end
end
