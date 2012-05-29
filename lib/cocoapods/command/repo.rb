require 'fileutils'

module Pod
  class Command
    class Repo < Command
      def self.banner
%{Managing spec-repos:

    $ pod repo add NAME URL

      Clones `URL' in the local spec-repos directory at `~/.cocoapods'. The
      remote can later be referred to by `NAME'.

    $ pod repo update NAME

      Updates the local clone of the spec-repo `NAME'. If `NAME' is omitted
      this will update all spec-repos in `~/.cocoapods'.}
      end

      extend Executable
      executable :git

      def initialize(argv)
        case @action = argv.arguments[0]
        when 'add'
          unless (@name = argv.arguments[1]) && (@url = argv.arguments[2])
            raise Informative, "#{@action == 'add' ? 'Adding' : 'Updating the remote of'} a repo needs a `name' and a `url'."
          end
        when 'update'
          @name = argv.arguments[1]
        else
          super
        end
      end

      def dir
        config.repos_dir + @name
      end

      def run
        send @action.gsub('-', '_')
      end

      def add
        puts "Cloning spec repo `#{@name}' from `#{@url}'" unless config.silent?
        config.repos_dir.mkpath
        Dir.chdir(config.repos_dir) { git("clone '#{@url}' #{@name}") }
        check_versions(dir)
      end

      def update
        dirs = @name ? [dir] : config.repos_dir.children.select {|c| c.directory?}
        dirs.each do |dir|
          puts "Updating spec repo `#{dir.basename}'" unless config.silent?
          Dir.chdir(dir) { git("pull") }
          check_versions(dir)
        end
      end

      def check_versions(dir)
        require 'yaml'
        bin_version  = Gem::Version.new(VERSION)
        yaml_file    = dir + 'CocoaPods-version.yml'
        return unless yaml_file.exist?
        data         = YAML.load_file(yaml_file)
        min_version  = Gem::Version.new(data[:min])
        max_version  = Gem::Version.new(data[:max])
        last_version = Gem::Version.new(data[:last])
        if min_version > bin_version || max_version < bin_version
          version_msg = ( min_version == max_version ) ? min_version : "#{min_version} - #{max_version}"
          raise Informative,
          "\n[!] The `#{dir.basename.to_s}' repo requires CocoaPods #{min_version}\n".red +
          "Update Cocoapods, or checkout the appropriate tag in the repo.\n\n"
        end
        puts "Cocoapods #{last_version} is available".green if last_version > bin_version
      end
    end
  end
end

