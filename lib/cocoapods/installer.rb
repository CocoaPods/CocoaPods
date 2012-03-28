module Pod
  class Installer
    autoload :TargetInstaller,       'cocoapods/installer/target_installer'
    autoload :UserProjectIntegrator, 'cocoapods/installer/user_project_integrator'

    include Config::Mixin

    attr_reader   :sandbox

    def initialize(podfile, user_project_path = nil)
      @podfile, @user_project_path = podfile, user_project_path
      # FIXME: pass this into the installer as a parameter
      @sandbox = Sandbox.new(config.project_pods_root)
      @resolver = Resolver.new(@podfile, @sandbox)
    end

    def lock_file
      config.project_root + 'Podfile.lock'
    end

    def project
      return @project if @project
      @project = Pod::Project.for_platform(@podfile.platform)
      # First we need to resolve dependencies across *all* targets, so that the
      # same correct versions of pods are being used for all targets. This
      # happens when we call `activated_specifications'.
      activated_specifications.each do |spec|
        # Add all source files to the project grouped by pod
        group = @project.add_pod_group(spec.name)
        spec.expanded_source_files.each do |path|
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
      activated_specifications.map do |spec|
        LocalPod.new(spec, sandbox).tap do |pod|
          marker = config.verbose ? "\n-> ".green : ''
          if pod.exists? || spec.local?
            puts marker + "Using #{pod}" unless config.silent?
          else
            puts marker + "Installing #{spec}".green unless config.silent?

            downloader = Downloader.for_pod(pod)
            downloader.download

            if config.clean
              downloader.clean
              pod.clean
            end

            if config.doc?
              puts "Installing Documentation for #{spec}".green if config.verbose?
              Generator::Documentation.new(pod).generate(config.doc_install?)
            end
          end
        end
      end
    end

    def install!
      @sandbox.prepare_for_install

      puts_title "Resolving dependencies of: #{@podfile.defined_in_file}"
      specs_by_target

      puts_title "Installing dependencies"
      pods = install_dependencies!

      puts_title("Generating support files\n", false)
      target_installers.each do |target_installer|
        target_specs = activated_specifications_for_target(target_installer.target_definition)
        pods_for_target = pods.select { |pod| target_specs.include?(pod.specification) }
        target_installer.install!(pods_for_target, sandbox)
      end

      generate_lock_file!(pods)

      puts "* Running post install hooks" if config.verbose?
      # Post install hooks run _before_ saving of project, so that they can alter it before saving.
      run_post_install_hooks

      puts "* Writing Xcode project file to `#{@sandbox.project_path}'\n\n" if config.verbose?
      project.save_as(@sandbox.project_path)

      UserProjectIntegrator.new(@user_project_path, @podfile).integrate! if @user_project_path
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
        pods.map do |pod|
          [pod.specification.to_s, pod.specification.dependencies.map(&:to_s).sort]
        end.sort_by(&:first).each do |name, deps|
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

    def specs_by_target
      @specs_by_target ||= @resolver.resolve
    end

    def dependency_specifications
      specs_by_target.values.flatten
    end

    def activated_specifications
      dependency_specifications.reject do |spec|
        # Don't activate specs which are only wrappers of subspecs, or share
        # source with another pod but aren't activated themselves.
        spec.wrapper? || @resolver.cached_sets[spec.name].only_part_of_other_pod?
      end
    end

    def activated_specifications_for_target(target_definition)
      specs_by_target[target_definition]
    end

    def download_only_specifications
      dependency_specifications - activated_specifications
    end

    private

    def puts_title(title, only_verbose = true)
      if(config.verbose?)
      puts "\n" + title.yellow
      elsif(!config.silent? && !only_verbose)
        puts title
      end
    end
  end
end
