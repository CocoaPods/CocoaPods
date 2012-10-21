module Pod

  # The {Source} class is responsible to manage a collection of podspecs.
  #
  # @note The backing store of the podspecs collection is an implementation detail
  # abstraced from the rest of CocoaPods.
  #
  # @note The default implementation uses a git repo as a backing store, where the
  # podspecs are namespaces as:
  #
  #     #{POD_NAME}/#{VERSION}/#{POD_NAME}.podspec
  #
  # @todo For better abstranction the sources should be responsible to update themselves.
  #
  class Source

    # @return [Pathname] The location of the repo.
    #
    attr_reader :repo

    # @param [Pathname] repo @see repo.
    #
    def initialize(repo)
      @repo = repo
    end

    # @return [String] the name of the repo.
    #
    def name
      @repo.basename.to_s
    end

    # @!group Quering the source

    # @return [Array<String>] The name of all the Pods.
    #
    def pods
      @repo.children.map do |child|
        child.basename.to_s if child.directory? && child.basename.to_s != '.git'
      end.compact
    end

    # @return [Array<Sets>] The sets of all the Pods.
    #
    def pod_sets
      pods.map { |pod| Specification::Set.new(pod, self) }
    end

    # @return [Array<Version>] All the available versions for the Pod, sorted
    #                          from highest to lowest.
    #
    # @param [String] name     The name of the Pod.
    #
    def versions(name)
      pod_dir = repo + name
      pod_dir.children.map do |v|
        basename = v.basename.to_s
        Version.new(basename) if v.directory? && basename[0,1] != '.'
      end.compact.sort.reverse
    end

    # @return [Specification]  The specification for a given version of Pod.
    #
    # @param [String] name     The name of the Pod.
    #
    # @param [Version,String] version
    #                          The version for the specification.
    #
    def specification(name, version)
      specification_path = repo + name + version.to_s + "#{name}.podspec"
      Specification.from_file(specification_path)
    end

    # @!group Searching the source

    # @return [Set] A set for a given dependency. The set is identified by the
    #               name of the dependency and takes into account subspecs.
    #
    def search(dependency)
      pod_sets.find do |set|
        # First match the (top level) name, which does not yet load the spec from disk
        set.name == dependency.top_level_spec_name &&
          # Now either check if it's a dependency on the top level spec, or if it's not
          # check if the requested subspec exists in the top level spec.
          set.specification.subspec_by_name(dependency.name)
      end
    end

    # @return [Array<Set>] The sets that contain the search term.
    #
    # @param [String] query           The search term.
    #
    # @param [Bool] full_text_search  Whether the search should be limited to
    #                                 the name of the Pod or should include
    #                                 also the author, the summary, and the
    #                                 description.
    #
    # @note Full text search requires to load the specification for each pod,
    #       hence is considerably slower.
    #
    def search_by_name(query, full_text_search = false)
      pod_sets.map do |set|
        text = if full_text_search
          s = set.specification
          "#{s.name} #{s.authors} #{s.summary} #{s.description}"
        else
          set.name
        end
        set if text.downcase.include?(query.downcase)
      end.compact
    end

    # The {Source::Aggregate} manages all the sources available to CocoaPods.
    #
    class Aggregate

      # @return [Array<Source>] All the sources.
      #
      def all
        @sources ||= dirs.map { |repo| Source.new(repo) }.sort_by(&:name)
      end

      # @return [Array<String>] The names of all the pods available.
      #
      def all_pods
        all.map(&:pods).flatten.uniq
      end

      # @return [Array<Set>] The sets for all the pods available.
      #
      # @note Implementation detail: The sources don't cache their values
      #       because they might change in response to an update. Therefore
      #       this method to prevent slowness caches the values before
      #       processing them.
      #
      def all_sets
        pods_by_source = {}
        all.each do |source|
          pods_by_source[source] = source.pods
        end
        sources = pods_by_source.keys
        pods = pods_by_source.values.flatten.uniq

        pods.map do |pod|
          pod_sources = sources.select{ |s| pods_by_source[s].include?(pod) }.compact
          Specification::Set.new(pod, pod_sources)
        end
      end

      # @return [Set] A set for a given dependency including all the Sources
      #               that countain the Pod.
      #
      # @raises       If no source including the set can be foud.
      #
      # @see          Source#search
      #
      def search(dependency)
        sources = all.select { |s| !s.search(dependency).nil? }
        raise(Informative, "[!] Unable to find a pod named `#{dependency.name}'".red) if sources.empty?
        Specification::Set.new(dependency.top_level_spec_name, sources)
      end

      # @return [Array<Set>]  The sets that contain the search term.
      #
      # @raises               If no source including the set can be foud.
      #
      # @see                  Source#search_by_name
      #
      def search_by_name(query, full_text_search = false)
        pods_by_source = {}
        result = []
        all.each { |s| pods_by_source[s] = s.search_by_name(query, full_text_search).map(&:name) }
        pod_names = pods_by_source.values.flatten.uniq
        pod_names.each do |pod|
          sources = []
          pods_by_source.each{ |source, pods| sources << source if pods.include?(pod) }
          result << Specification::Set.new(pod, sources)
        end
        if result.empty?
          extra = ", author, summary, or description" if full_text_search
          raise(Informative, "Unable to find a pod with name" \
                "#{extra} matching `#{query}'")
        end
        result
      end

      # @return [Array<Pathname>] The directories where the sources are stored.
      #
      # @raises If the repos dir doesn't exits.
      #
      def dirs
        if ENV['CP_MASTER_REPO_DIR']
          [Pathname.new(ENV['CP_MASTER_REPO_DIR'])]
        else
          repos_dir = Config.instance.repos_dir
          unless repos_dir.exist?
            raise Informative, "No spec repos found in `#{repos_dir}'. " \
              "To fetch the `master' repo run: $ pod setup"
          end
          repos_dir.children.select(&:directory?)
        end
      end
    end

    # @!group Shortcuts

    def self.all
      Aggregate.new.all
    end

    def self.all_sets
      Aggregate.new.all_sets
    end

    def self.search(dependency)
      Aggregate.new.search(dependency)
    end

    def self.search_by_name(name, full_text_search = false)
      Aggregate.new.search_by_name(name, full_text_search)
    end
  end
end
