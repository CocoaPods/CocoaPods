module Pod
  class Source
    class << self

      include Config::Mixin

      # @return [Array<Source>] the list of all the sources known to this
      #         installation of CocoaPods.
      #
      def all
        Aggregate.new(config.repos_dir).all
      end

      # @return [Array<Specification::Set>] the list of all the specification
      #         sets know to this installation of CocoaPods.
      #
      def all_sets
        Aggregate.new(config.repos_dir).all_sets
      end

      # Search all the sources to match the set for the given dependency.
      #
      # @return [Set, nil] a set for a given dependency including all the
      #         {Source} that contain the Pod. If no sources containing the
      #         Pod where found it returns nil.
      #
      # @todo   Move exceptions to clients?
      #
      # @raise  If no source including the set can be found.
      #
      def search(dependency)
        set = Aggregate.new(config.repos_dir).search(dependency)
        raise Informative, "Unable to find a pod named `#{dependency.name}`" unless set
        set
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
      # @todo   Move exceptions to clients?
      #
      # @return [Array<Set>]  The sets that contain the search term.
      #
      def search_by_name(query, full_text_search = false)
        result = Aggregate.new(config.repos_dir).search_by_name(query, full_text_search)
        if result.empty?
          extra = ", author, summary, or description" if full_text_search
          raise Informative "Unable to find a pod with name#{extra} matching `#{query}'"
        end
        result
      end
    end
  end
end
