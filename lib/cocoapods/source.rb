module Pod
  class Source
    def self.all
      @sources ||= begin
        repos_dir = Config.instance.repos_dir
        unless repos_dir.exist?
          raise Informative, "No spec repos found in `#{repos_dir}'. " \
                             "To fetch the `master' repo run: $ pod setup"
        end
        repos_dir.children.select(&:directory?).map { |repo| new(repo) }
      end
    end

    def self.search(dependency)
      all.map { |s| s.search(dependency) }.compact.first ||
        raise(Informative, "Unable to find a pod named `#{dependency.name}'")
    end

    def self.search_by_name(query, full_text_search)
      result = all.map { |s| s.search_by_name(query, full_text_search) }.flatten
      if result.empty?
        raise(Informative, "Unable to find a pod who's name matches `#{query}'")
      end
      result
    end

    attr_reader :repo

    def initialize(repo)
      @repo = repo
    end

    def pod_sets
      @repo.children.map do |child|
        if child.directory? && child.basename.to_s != '.git'
          Specification::Set.by_pod_dir(child)
        end
      end.compact
    end

    def search(dependency)
      pod_sets.find { |set| set.name == dependency.name }
    end

    def search_by_name(query, full_text_search)
      pod_sets.map do |set|
        text = if full_text_search
          s = set.specification
          "#{s.read(:name)} #{s.read(:summary)} #{s.read(:description)}"
        else
          set.name
        end
        set if text.downcase.include?(query.downcase)
      end.compact
    end
  end
end
