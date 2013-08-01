module Pod

  # Manages all the sources known to the running CocoaPods Instance.
  #
  class SourcesManager

    class << self

      include Config::Mixin

      # @return [Source::Aggregate] the aggregate of all the sources known to
      #         this installation of CocoaPods.
      #
      def aggregate
        Source::Aggregate.new(config.repos_dir)
      end

      # @return [Array<Source>] the list of all the sources known to this
      #         installation of CocoaPods.
      #
      def all
        aggregate.all
      end

      # @return [Array<Specification::Set>] the list of all the specification
      #         sets know to this installation of CocoaPods.
      #
      def all_sets
        aggregate.all_sets
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
          updated_search_index.each do |name, set_data|
            text = name.dup
            if full_text_search
              text << set_data['authors'].to_s if set_data['authors']
              text << set_data['summary']      if set_data['summary']
              text << set_data['description']  if set_data['description']
            end
            set_names << name if text.downcase.include?(query.downcase)
          end
          sets = set_names.sort.map { |name| aggregate.represenative_set(name) }
        else
          sets = aggregate.search_by_name(query, false)
        end
        if sets.empty?
          extra = ", author, summary, or description" if full_text_search
          raise Informative, "Unable to find a pod with name#{extra} matching `#{query}`"
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

          File.open(search_index_path, 'w') {|f| f.write(search_index.to_yaml) }
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

      public

      # @!group Updating Sources
      #-----------------------------------------------------------------------#

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
          specified_source = aggregate.all.find { |s| s.name == source_name }
          raise Informative, "Unable to find the `#{source_name}` repo."    unless specified_source
          raise Informative, "The `#{source_name}` repo is not a git repo." unless git_repo?(specified_source.repo)
          sources = [specified_source]
        else
          sources = aggregate.all.select { |source| git_repo?(source.repo) }
        end

        sources.each do |source|
          UI.section "Updating spec repo `#{source.name}`" do
            Dir.chdir(source.repo) do
              output = git!("pull")
              UI.puts output if show_output && !config.verbose?
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
      # @return [Bool] Wether the given source is a GIT repo.
      #
      def git_repo?(dir)
        Dir.chdir(dir) { `git rev-parse  >/dev/null 2>&1` }
        $?.exitstatus.zero?
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
          version_msg = ( min == max ) ? min : "#{min} - #{max}"
          raise Informative, "The `#{dir.basename}` repo requires " \
          "CocoaPods #{version_msg}\n".red +
          "Update CocoaPods, or checkout the appropriate tag in the repo."
        end

        if config.new_version_message? && cocoapods_update?(versions)
          UI.puts "\nCocoaPods #{versions['last']} is available.\n".green
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
        yaml_file.exist? ? YAML.load_file(yaml_file) : {}
      end

      public

      # @!group Master repo
      #-----------------------------------------------------------------------#

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

      #-----------------------------------------------------------------------#

    end
  end
end

