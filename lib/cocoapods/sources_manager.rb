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
        return Source::Aggregate.new([]) unless config.repos_dir.exist?
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
          rescue Informative
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

      # Returns the source whose {Source#name} or {Source#url} is equal to the
      # given `name_or_url`.
      #
      # @return [Source] The source whose {Source#name} or {Source#url} is equal to the
      #                  given `name_or_url`.
      #
      # @param  [String] name_or_url
      #                  The name or the URL of the source.
      #
      def source_with_name_or_url(name_or_url)
        all.find { |s| s.name == name_or_url } ||
          find_or_create_source_with_url(name_or_url)
      end

      # @return [Array<Source>] The list of all the sources known to this
      #         installation of CocoaPods.
      #
      def all
        return [] unless config.repos_dir.exist?
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
      # @return [Array<Set>]  The sets that contain the search term.
      #
      def search_by_name(query, full_text_search = false)
        query_word_regexps = query.split.map { |word| /#{word}/i }
        if full_text_search
          query_word_results_hash = {}
          updated_search_index.each_value do |word_spec_hash|
            word_spec_hash.each_pair do |word, spec_symbols|
              query_word_regexps.each do |query_word_regexp|
                set = (query_word_results_hash[query_word_regexp] ||= Set.new)
                set.merge(spec_symbols) if word =~ query_word_regexp
              end
            end
          end
          found_set_symbols = query_word_results_hash.values.reduce(:&)
          found_set_symbols ||= []
          sets = found_set_symbols.map do |symbol|
            aggregate.representative_set(symbol.to_s)
          end
          # Remove nil values because representative_set return nil if no pod is found in any of the sources.
          sets.compact!
        else
          sets = aggregate.search_by_name(query, false)
        end
        if sets.empty?
          extra = ', author, summary, or description' if full_text_search
          raise Informative, "Unable to find a pod with name#{extra}" \
            "matching `#{query}`"
        end
        sorted_sets(sets, query_word_regexps)
      end

      # Returns given set array by sorting it in-place.
      #
      # @param  [Array<Set>] sets
      #         Array of sets to be sorted.
      #
      # @param  [Array<Regexp>] query_word_regexps
      #         Array of regexp objects for user query.
      #
      # @return [Array<Set>]  Given sets parameter itself after sorting it in-place.
      #
      def sorted_sets(sets, query_word_regexps)
        sets.sort_by! do |set|
          pre_match_length = nil
          found_query_index = nil
          found_query_count = 0
          query_word_regexps.each_with_index do |q, idx|
            if (m = set.name.match(/#{q}/i))
              pre_match_length ||= (m.pre_match.length)
              found_query_index ||= idx
              found_query_count += 1
            end
          end
          pre_match_length ||= 1000
          found_query_index ||= 1000
          [-found_query_count, pre_match_length, found_query_index, set.name.downcase]
        end
        sets
      end

      # Returns the search data. If a saved search data exists, retrieves it from file and returns it.
      # Else, creates the search data from scratch, saves it to file system, and returns it.
      # Search data is grouped by source repos. For each source, it contains a hash where keys are words
      # and values are the pod names containing corresponding word.
      #
      # For each source, list of unique words are generated from the following spec information.
      #   - version
      #   - summary
      #   - description
      #   - authors
      #
      # @return [Hash{String => Hash{String => Array<String>}}] The up to date search data.
      #
      def updated_search_index
        index = stored_search_index || {}
        all.each do |source|
          source_name = source.name
          unless index[source_name]
            UI.print "Creating search index for spec repo '#{source_name}'.."
            index[source_name] = aggregate.generate_search_index_for_source(source)
            UI.puts ' Done!'
          end
        end
        save_search_index(index)
        index
      end

      # Returns the search data stored in the file system.
      # If existing data in the file system is not valid, returns nil.
      #
      def stored_search_index
        unless @updated_search_index
          if search_index_path.exist?
            require 'json'
            index = JSON.parse(search_index_path.read)
            if index && index.is_a?(Hash) # TODO: should we also check if hash has correct hierarchy?
              return @updated_search_index = index
            end
          end
          @updated_search_index = nil
        end
        @updated_search_index
      end

      # Stores given search data in the file system.
      # @param [Hash] index
      #        Index to be saved in file system
      #
      def save_search_index(index)
        require 'json'
        @updated_search_index = index
        search_index_path.open('w') do |io|
          io.write(@updated_search_index.to_json)
        end
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

      # Updates the stored search index if there are changes in spec repos while updating them.
      # Update is performed incrementally. Only the changed pods' search data is re-generated and updated.
      # @param  [Hash{Source => Array<String>}] changed_spec_paths
      #                  A hash containing changed specification paths for each source.
      #
      def update_search_index_if_needed(changed_spec_paths)
        search_index = stored_search_index
        return unless search_index
        changed_spec_paths.each_pair do |source, spec_paths|
          index_for_source = search_index[source.name]
          next unless index_for_source && spec_paths.length > 0
          updated_pods = source.pods_for_specification_paths(spec_paths)

          new_index = aggregate.generate_search_index_for_changes_in_source(source, spec_paths)
          # First traverse search_index and update existing words
          # Removed traversed words from new_index after adding to search_index,
          # so that only non existing words will remain in new_index after enumeration completes.
          index_for_source.each_pair do |word, _|
            if new_index[word]
              index_for_source[word] |= new_index[word]
            else
              index_for_source[word] -= updated_pods
            end
          end
          # Now add non existing words remained in new_index to search_index
          index_for_source.merge!(new_index)
        end
        save_search_index(search_index)
      end

      # Updates search index for changed pods in background
      # @param  [Hash{Source => Array<String>}] changed_spec_paths
      #                  A hash containing changed specification paths for each source.
      #
      def update_search_index_if_needed_in_background(changed_spec_paths)
        Process.fork do
          Process.daemon
          update_search_index_if_needed(changed_spec_paths)
          exit
        end
      end

      # Updates the local clone of the spec-repo with the given name or of all
      # the git repos if the name is omitted.
      #
      # @param  [String] source_name
      #
      # @param  [Bool] show_output
      #
      # @return [void]
      #
      def update(source_name = nil, show_output = false)
        if source_name
          sources = [git_source_named(source_name)]
        else
          sources =  git_sources
        end

        changed_spec_paths = {}
        sources.each do |source|
          UI.section "Updating spec repo `#{source.name}`" do
            changed_source_paths = source.update(show_output && !config.verbose?)
            changed_spec_paths[source] = changed_source_paths if changed_source_paths.count > 0
            check_version_information(source.repo)
          end
        end
        # Perform search index update operation in background.
        update_search_index_if_needed_in_background(changed_spec_paths)
      end

      # Returns whether a source is a GIT repo.
      #
      # @param  [Pathname] dir
      #         The directory where the source is stored.
      #
      # @return [Bool] Whether the given source is a GIT repo.
      #
      def git_repo?(dir)
        Dir.chdir(dir) { `git rev-parse >/dev/null 2>&1` }
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
          min = versions['min']
          max = versions['max']
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
            ("Until we reach version 1.0 the features of CocoaPods can and will change.\n" \
             'We strongly recommend that you use the latest version at all times.'.yellow unless rc),
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

        min = versions['min']
        max = versions['max']
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
        yaml_file = dir + 'CocoaPods-version.yml'
        return {} unless yaml_file.exist?
        begin
          YAMLHelper.load_file(yaml_file)
        rescue Informative
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
        aggregate.sources.find do |source|
          source.url && source.url.downcase.gsub(/.git$/, '') == url
        end
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

          base + path.gsub(/.git$/, '').gsub(/^\//, '').split('/').join('-')
        end

        case url.to_s.downcase
        when %r{github.com[:/]+cocoapods/specs}
          base = 'master'
        when %r{github.com[:/]+(.+)/(.+)}
          base = Regexp.last_match[1]
        when /^\S+@(\S+)[:\/]+(.+)$/
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

  class Source
    extend Executable
    executable :git

    def update_git_repo(show_output = false)
      output = git! %w(pull --ff-only)
      UI.puts output if show_output
    rescue
      UI.warn 'CocoaPods was not able to update the ' \
                "`#{name}` repo. If this is an unexpected issue " \
                'and persists you can inspect it running ' \
                '`pod repo update --verbose`'
    end
  end
end
