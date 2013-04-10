module Pod
  class Command

    # Provides support the common behaviour of the `install` and `update`
    # commands.
    #
    module Project
      module Options
        def options
          [
            ["--no-clean",       "Leave SCM dirs like `.git' and `.svn' intact after downloading"],
            ["--no-doc",         "Skip documentation generation with appledoc"],
            ["--no-integrate",   "Skip integration of the Pods libraries in the Xcode project(s)"],
            ["--no-repo-update", "Skip running `pod repo update` before install"],
          ].concat(super)
        end
      end

      def self.included(base)
        base.extend Options
      end

      def initialize(argv)
        config.clean = argv.flag?('clean', config.clean)
        config.generate_docs = argv.flag?('doc', config.generate_docs)
        config.integrate_targets = argv.flag?('integrate', config.integrate_targets)
        config.skip_repo_update = !argv.flag?('repo-update', !config.skip_repo_update)
        super
      end

      # Runs the installer.
      #
      # @param  [update] whether the installer should be run in update mode.
      #
      # @return [void]
      #
      def run_install_with_update(update)
        installer = Installer.new(config.sandbox, config.podfile, config.lockfile)
        installer.update_mode = update
        installer.install!
      end
    end

    #-------------------------------------------------------------------------#

    class Install < Command
      include Project

      self.summary = 'Install project dependencies'

      self.description = <<-DESC
        Downloads all dependencies defined in `Podfile' and creates an Xcode
        Pods library project in `./Pods'.

        The Xcode project file should be specified in your `Podfile` like this:

          xcodeproj 'path/to/XcodeProject'

        If no xcodeproj is specified, then a search for an Xcode project will
        be made.  If more than one Xcode project is found, the command will
        raise an error.

        This will configure the project to reference the Pods static library,
        add a build configuration file, and add a post build script to copy
        Pod resources.
      DESC

      def run
        verify_podfile_exists!
        run_install_with_update(false)
      end
    end

    #-------------------------------------------------------------------------#

    class Update < Command
      include Project

      self.summary = 'Update outdated project dependencies'

      def run
        verify_podfile_exists!
        verify_lockfile_exists!
        run_install_with_update(true)
      end
    end

    class PodfileInfo < Command

      self.summary = 'Shows information on installed Pods.'
      self.description = <<-DESC
        Shows information on installed Pods in current Project. 
        If optional `PODFILE_PATH` provided, the info will be shown for
        that specific Podfile
      DESC
      self.arguments = '[PODFILE_PATH]'

      def self.options
        [
          # ["--all", "Show information about all Pods with dependencies that are used in a project"],
          ["--md", "Output information in Markdown format"]
        ].concat(super)
      end

      def initialize(argv)
        @info_all = argv.flag?('all')
        @info_in_md = argv.flag?('md')
        @podfile_path = argv.shift_argument
        super
      end

      def run
        use_podfile = (@podfile_path || !config.lockfile)
          
        if !use_podfile
          UI.puts "Using lockfile" if config.verbose?
          verify_lockfile_exists!
          lockfile = config.lockfile
          # pods = (@info_all) ? lockfile.dependencies : lockfile.pod_names
          pods = lockfile.pod_names
        elsif @podfile_path
          podfile = Pod::Podfile.from_file(@podfile_path)
          pods = pods_from_podfile(podfile)
        else
          verify_podfile_exists!
          podfile = config.podfile
          pods = pods_from_podfile(podfile)
        end

        UI.puts "\nPods used:\n".yellow unless (config.silent || @info_in_md)
        pods_info(pods, @info_in_md)
      end

      def pods_from_podfile(podfile)
        pods = []
        podfile.root_target_definitions.each {|e| h = e.to_hash; pods << h['dependencies'] if h['dependencies']}
        pods.flatten!
        pods.collect! {|pod| (pod.is_a?(Hash)) ? pod.keys.first : pod}
      end

      def pods_info_hash(pods, keys=[:name, :homepage, :summary])
        pods_info = []
        pods.each do |pod|
          spec = (Pod::SourcesManager.search_by_name(pod).first rescue nil)
          if spec
            info = {}
            keys.each { |k| info[k] = spec.specification.send(k) }
            pods_info << info
          else
            
          end
          
        end
        pods_info
      end

      def pods_info(pods, in_md=false)
        pods = pods_info_hash(pods, [:name, :homepage, :summary])

        pods.each do |pod| 
          if in_md
            UI.puts "* [#{pod[:name]}](#{pod[:homepage]}) - #{pod[:summary]}" 
          else
            UI.puts "- #{pod[:name]} - #{pod[:summary]}" 
          end
        end
      end

    end

  end
end

