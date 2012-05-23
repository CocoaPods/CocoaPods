module Pod
  class Source
    class Aggregate
      def all
        @sources ||= begin
          repos_dir = Config.instance.repos_dir
          unless repos_dir.exist?
            raise Informative, "No spec repos found in `#{repos_dir}'. " \
                               "To fetch the `master' repo run: $ pod setup"
          end
          repos_dir.children.select(&:directory?).map { |repo| Source.new(repo) }
        end
      end

      def all_sets
        all.map(&:pod_sets).flatten
      end

      def search(dependency)
        all.map { |s| s.search(dependency) }.compact.first ||
          raise(Informative, "[!] Unable to find a pod named `#{dependency.name}'".red)
      end

      def search_by_name(query, full_text_search)
        result = all.map { |s| s.search_by_name(query, full_text_search) }.flatten
        if result.empty?
          extra = ", author, summary, or description" if full_text_search
          raise(Informative, "Unable to find a pod with name" \
                             "#{extra} matching `#{query}'")
        end
        result
      end
    end

    def self.all
      Aggregate.new.all
    end

    def self.all_sets
      Aggregate.new.all_sets
    end

    def self.search(dependency)
      Aggregate.new.search(dependency)
    end

    def self.search_by_name(name, full_text_search)
      Aggregate.new.search_by_name(name, full_text_search)
    end

    attr_reader :repo

    def initialize(repo)
      @repo = repo
    end

    def pod_sets
      @repo.children.map do |child|
        if child.directory? && child.basename.to_s != '.git'
          Specification::Set.new(child)
        end
      end.compact
    end

    def search(dependency)
      pod_sets.find do |set|
        # First match the (top level) name, which does not yet load the spec from disk
        set.name == dependency.top_level_spec_name &&
          # Now either check if it's a dependency on the top level spec, or if it's not
          # check if the requested subspec exists in the top level spec.
          set.specification.subspec_by_name(dependency.name)
      end
    end

    def search_by_name(query, full_text_search)
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
  end
end
