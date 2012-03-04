module Pod
  class Installer
    autoload :TargetInstaller, 'cocoapods/installer/target_installer'

    include Config::Mixin
    
    attr_reader :sandbox

    def initialize(podfile)
      @podfile = podfile
      
      # FIXME: pass this into the installer as a parameter
      @sandbox = Sandbox.new(config.project_pods_root)
    end

    def lock_file
      config.project_root + 'Podfile.lock'
    end

    def project
      return @project if @project
      @project = Pod::Project.for_platform(@podfile.platform)
      # First we need to resolve dependencies across *all* targets, so that the
      # same correct versions of pods are being used for all targets. This
      # happens when we call `build_specifications'.
      build_specifications.each do |spec|
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
      build_specifications.map do |spec|
        LocalPod.new(spec, sandbox).tap do |pod|
          if pod.exists? || spec.local?
            puts "Using #{pod}" unless config.silent?
          else
            puts "Installing #{spec}" unless config.silent?

            downloader = Downloader.for_pod(pod)
            downloader.download

            if config.clean
              downloader.clean
              pod.clean
            end
          end
        end
      end
    end

    def install!
      @sandbox.prepare_for_install
      
      puts "Installing dependencies of: #{@podfile.defined_in_file}" if config.verbose?
      pods = install_dependencies!

      puts "Generating support files" unless config.silent?
      target_installers.each do |target_installer|
        target_specs = build_specifications_for_target(target_installer.target_definition)
        pods_for_target = pods.select { |pod| target_specs.include?(pod.specification) }
        target_installer.install!(pods_for_target, sandbox)
      end
      
      generate_lock_file!(pods)

      puts "* Running post install hooks" if config.verbose?
      # Post install hooks run _before_ saving of project, so that they can alter it before saving.
      run_post_install_hooks

      puts "* Writing Xcode project file to `#{@sandbox.project_path}'" if config.verbose?
      project.save_as(@sandbox.project_path)
    end
    
    def run_post_install_hooks
      # we loop over target installers instead of pods, because we yield the target installer
      # to the spec post install hook.
      
      target_installers.each do |target_installer|
        build_specifications_for_target(target_installer.target_definition).each do |spec|    
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
    
    def dependent_specifications_for_each_target_definition
      @dependent_specifications_for_each_target_definition ||= Resolver.new(@podfile, @sandbox).resolve
    end
    
    def dependent_specifications
      dependent_specifications_for_each_target_definition.values.flatten
    end

    def build_specifications
      dependent_specifications.reject do |spec|
        spec.wrapper? || spec.defined_in_set.only_part_of_other_pod?
      end
    end
    
    def build_specifications_for_target(target_definition)
      dependent_specifications_for_each_target_definition[target_definition]
    end

    def download_only_specifications
      dependent_specifications - build_specifications
    end
  end
end
