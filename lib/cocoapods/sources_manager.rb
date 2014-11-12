module Pod
  # Manages all the sources known to the running CocoaPods Instance.
  #
  class SourcesManager
    class << self
      include Config::Mixin

      # @return [Source::Aggregate] The aggregate of all the sources with the
      #         known Pods.
      #
      def aggregate
        dirs = config.repos_dir.children.select(&:directory?)
        Source::Aggregate.new(dirs)
      end

      # @return [Array<Source>] The list of the sources with the given names.
      #
      # @param  [Array<#to_s>] names
      #         The names of the sources.
      #
      def sources(names)
        dirs = names.map { |name| source_dir(name) }
        dirs.map { |repo| Source.new(repo) }
      end

      # Returns the source whose {Source#url} is equal to `url`, adding the repo
      # in a manner similarly to `pod repo add` if it is not found.
      #
      # @raise  If no source with the given `url` could be created,
      #
      # @return [Source] The source whose {Source#url} is equal to `url`,
      #
      # @param  [String] url
      #         The URL of the source.
      #
      def find_or_create_source_with_url(url)
        unless source = source_with_url(url)
          name = name_for_url(url)
          # Hack to ensure that `repo add` output is shown.
          previous_title_level = UI.title_level
          UI.title_level = 0
          begin
            argv = [name, url]
            argv << '--shallow' if name =~ /^master(-\d+)?$/
            Command::Repo::Add.new(CLAide::ARGV.new(argv)).run
          rescue Informative => e
            raise Informative, "Unable to add a source with url `#{url}` " \
              "named `#{name}`.\nYou can try adding it manually in " \
              '`~/.cocoapods/repos` or via `pod repo add`.'
          ensure
            UI.title_level = previous_title_level
          end
          source = source_with_url(url)
        end

        source
      end

      # @return [Array<Source>] The list of all the sources known to this
      #         installation of CocoaPods.
      #
      def all
        dirs = config.repos_dir.children.select(&:directory?)
        dirs.map { |repo| Source.new(repo) }
      end

      # @return [Array<Source>] The CocoaPods Master Repo source.
      #
      def master
        sources(['master'])
      end

      # Search all the sources to match the set for the given dependency.
      #
      # @return [Set, nil] a set for a given dependency including all the
      #         {Source} that contain the Pod. If no sources containing the
      #         Pod where found it returns nil.
      #
      # @raise  If no source including the set can be found.
      #
      def search(dependency)
        aggregate.search(dependency)
      end

      # Search all the sources with the given search term.
      #
      # @param  [String] query
      #         The search term.
      #
      # @param  [Bool] full_text_search
      #         Whether the search should be limited to the name of the Pod or
      #         should include also the author, the summary, and the
      #         description.
      #
      # @raise  If no source including the set can be found.
      #
      # @note   Full text search requires to load the specification for each
      #         pod, hence is considerably slower.
      #
      # @return [Array<Set>]  The sets that contain the search term.
      #
      def search_by_name(query, full_text_search = false)
        if full_text_search
          set_names = []
          query_regexp = /#{query}/i
          updated_search_index.each do |name, set_data|
            texts = [name]
            if full_text_search
              texts << set_data['authors'].to_s if set_data['authors']
              texts << set_data['summary']      if set_data['summary']
              texts << set_data['description']  if set_data['description']
            end
            set_names << name unless texts.grep(query_regexp).empty?
          end
          sets = set_names.sort.map do |name|
            aggregate.representative_set(name)
          end
        else
          sets = aggregate.search_by_name(query, false)
        end
        if sets.empty?
          extra = ', author, summary, or description' if full_text_search
          raise Informative, "Unable to find a pod with name#{extra}" \
            "matching `#{query}`"
        end
        sets
      end

      # Creates or updates the search data and returns it. The search data
      # groups by name the following information for each set:
      #
      #   - version
      #   - summary
      #   - description
      #   - authors
      #
      # @note   This operation is fairly expensive, because of the YAML
      #         conversion.
      #
      # @return [Hash{String => String}] The up to date search data.
      #
      def updated_search_index
        unless @updated_search_index
          if search_index_path.exist?
            stored_index = YAML.load(search_index_path.read)
            if stored_index && stored_index.is_a?(Hash)
              search_index = aggregate.update_search_index(stored_index)
            else
              search_index = aggregate.generate_search_index
            end
          else
            search_index = aggregate.generate_search_index
          end

          File.open(search_index_path, 'w') do |file|
            file.write(search_index.to_yaml)
          end
          @updated_search_index = search_index
        end
        @updated_search_index
      end

      # Allows to clear the search index.
      #
      attr_writer :updated_search_index

      # @return [Pathname] The path where the search index should be stored.
      #
      def search_index_path
        Config.instance.search_index_file
      end

      # @!group Updating Sources

      extend Executable
      executable :git

      # Updates the local clone of the spec-repo with the given name or of all
      # the git repos if the name is omitted.
      #
      # @param  [String] name
      #
      # @return [void]
      #
      def update(source_name = nil, show_output = false)
        if source_name
          sources = [git_source_named(source_name)]
        else
          sources =  git_sources
        end

        sources.each do |source|
          UI.section "Updating spec repo `#{source.name}`" do
            Dir.chdir(source.repo) do
              begin
                output = git!('pull --ff-only')
                UI.puts output if show_output && !config.verbose?
              rescue Informative => e
                UI.warn 'CocoaPods was not able to update the ' \
                  "`#{source.name}` repo. If this is an unexpected issue " \
                  'and persists you can inspect it running ' \
                  '`pod repo update --verbose`'
              end
            end
            check_version_information(source.repo)
          end
        end
      end

      # Returns whether a source is a GIT repo.
      #
      # @param  [Pathname] dir
      #         The directory where the source is stored.
      #
      # @return [Bool] Whether the given source is a GIT repo.
      #
      def git_repo?(dir)
        Dir.chdir(dir) { git('rev-parse  >/dev/null 2>&1') }
        $?.success?
      end

      # Checks the version information of the source with the given directory.
      # It raises if the source is not compatible and if there is CocoaPods
      # update it informs the user.
      #
      # @param  [Pathname] dir
      #         The directory where the source is stored.
      #
      # @raise  If the source is not compatible.
      #
      # @return [void]
      #
      def check_version_information(dir)
        versions = version_information(dir)
        unless repo_compatible?(dir)
          min, max = versions['min'], versions['max']
          version_msg = (min == max) ? min : "#{min} - #{max}"
          raise Informative, "The `#{dir.basename}` repo requires " \
          "CocoaPods #{version_msg} (currently using #{Pod::VERSION})\n".red +
            'Update CocoaPods, or checkout the appropriate tag in the repo.'
        end

        needs_sudo = path_writable?(__FILE__)

        if config.new_version_message? && cocoapods_update?(versions)
          last = versions['last']
          rc = Gem::Version.new(last).prerelease?
          install_message = needs_sudo ? 'sudo ' : ''
          install_message << 'gem install cocoapods'
          install_message << ' --pre' if rc
          message = [
            "CocoaPods #{versions['last']} is available.".green,
            "To update use: `#{install_message}`".green,
            ("[!] This is a test version we'd love you to try.".yellow if rc),
            '',
            'For more information see http://blog.cocoapods.org'.green,
            'and the CHANGELOG for this version http://git.io/BaH8pQ.'.green,
            '',
          ].compact.join("\n")
          UI.puts("\n#{message}\n")
        end
      end

      # Returns whether a source is compatible with the current version of
      # CocoaPods.
      #
      # @param  [Pathname] dir
      #         The directory where the source is stored.
      #
      # @return [Bool] whether the source is compatible.
      #
      def repo_compatible?(dir)
        versions = version_information(dir)

        min, max = versions['min'], versions['max']
        bin_version  = Gem::Version.new(Pod::VERSION)
        supports_min = !min || bin_version >= Gem::Version.new(min)
        supports_max = !max || bin_version <= Gem::Version.new(max)
        supports_min && supports_max
      end

      # Checks whether there is a CocoaPods given the version information of a
      # repo.
      #
      # @param  [Hash] version_information
      #         The version information of a repository.
      #
      # @return [Bool] whether there is an update.
      #
      def cocoapods_update?(version_information)
        version = version_information['last']
        version && Gem::Version.new(version) > Gem::Version.new(Pod::VERSION)
      end

      # Returns the contents of the `CocoaPods-version.yml` file, which stores
      # information about CocoaPods versions.
      #
      # This file is a hash with the following keys:
      #
      # - last: the last version of CocoaPods known to the source.
      # - min: the minimum version of CocoaPods supported by the source.
      # - max: the maximum version of CocoaPods supported by the source.
      #
      # @param  [Pathname] dir
      #         The directory where the source is stored.
      #
      # @return [Hash] the versions information from the repo.
      #
      def version_information(dir)
        require 'yaml'
        yaml_file  = dir + 'CocoaPods-version.yml'
        return {} unless yaml_file.exist?
        begin
          YAMLHelper.load_file(yaml_file)
        rescue Informative => e
          raise Informative, "There was an error reading '#{yaml_file}'.\n" \
            'Please consult http://blog.cocoapods.org/' \
            'Repairing-Our-Broken-Specs-Repository/ ' \
            'for more information.'
        end
      end

      # @!group Master repo

      # @return [Pathname] The path of the master repo.
      #
      def master_repo_dir
        config.repos_dir + 'master'
      end

      # @return [Bool] Checks if the master repo is usable.
      #
      # @note   Note this is used to automatically setup the master repo if
      #         needed.
      #
      def master_repo_functional?
        master_repo_dir.exist? && repo_compatible?(master_repo_dir)
      end

      private

      # @return [Bool] Whether the given path is writable by the current user.
      #
      # @param  [#to_s] path
      #         The path.
      #
      def path_writable?(path)
        Pathname(path).dirname.writable?
      end

      # @return [Source] The git source with the given name. If no git source
      #         with given name is found it raises.
      #
      # @param  [String] name
      #         The name of the source.
      #
      def git_source_named(name)
        specified_source = aggregate.sources.find { |s| s.name == name }
        unless specified_source
          raise Informative, "Unable to find the `#{name}` repo."
        end
        unless git_repo?(specified_source.repo)
          raise Informative, "The `#{name}` repo is not a git repo."
        end
        specified_source
      end

      # @return [Source] The list of the git sources.
      #
      def git_sources
        all.select do |source|
          git_repo?(source.repo)
        end
      end

      # @return [Pathname] The path of the source with the given name.
      #
      # @param  [String] name
      #         The name of the source.
      #
      def source_dir(name)
        if dir = config.repos_dir + name
          dir
        else
          raise Informative, "Unable to find the `#{name}` repo."
        end
      end

      # @return [Source] The source whose {Source#url} is equal to `url`.
      #
      # @param  [String] url
      #         The URL of the source.
      #
      def source_with_url(url)
        url = url.downcase.gsub(/.git$/, '')
        aggregate.sources.find { |s| s.url.downcase.gsub(/.git$/, '') == url }
      end

      # Returns a suitable repository name for `url`.
      #
      # @example A GitHub.com URL
      #
      #          name_for_url('https://github.com/Artsy/Specs.git')
      #            # "artsy"
      #          name_for_url('https://github.com/Artsy/Specs.git')
      #            # "artsy-1"
      #
      # @example A non-Github.com URL
      #
      #          name_for_url('https://sourceforge.org/Artsy/Specs.git')
      #            # sourceforge-artsy-specs
      #
      # @example A file URL
      # 
      #           name_for_url('file:///Artsy/Specs.git')
      #             # artsy-specs
      #
      # @param  [#to_s] url
      #         The URL of the source.
      #
      # @return [String] A suitable repository name for `url`.
      #
      def name_for_url(url)
        base_from_host_and_path = lambda do |host, path|
          if host
            base = host.split('.')[-2] || host
            base += '-'
          else
            base = ''
          end
          base += path.gsub(/.git$/, '').gsub(/^\//, '').
            split('/').join('-')
        end

        case url.to_s.downcase
        when %r{github.com[:/]+cocoapods/specs}
          base = 'master'
        when %r{github.com[:/]+(.+)/(.+)}
          base = Regexp.last_match[1]
        when %r{^\S+@(\S+)[:/]+(.+)$}
          host, path = Regexp.last_match.captures
          base = base_from_host_and_path[host, path]
        when URI.regexp
          url = URI(url.downcase)
          base = base_from_host_and_path[url.host, url.path]
        else
          base = url.to_s.downcase
        end

        name = base
        infinity = 1.0 / 0
        (1..infinity).each do |i|
          break unless source_dir(name).exist?
          name = "#{base}-#{i}"
        end
        name
      end
    end
  end
end
