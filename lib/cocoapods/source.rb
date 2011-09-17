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
      all.map { |source| source.search(dependency) }.compact.first ||
        raise(Informative, "Unable to find a pod named `#{dependency.name}'")
    end

    def self.search_by_name(query)
      result = all.map { |source| source.search_by_name(query) }.flatten
      if result.empty?
        raise(Informative, "Unable to find a pod who's name matches `#{query}'")
      end
      result
    end

    attr_reader :repo

    def initialize(repo)
      @repo = repo
    end

    def search(dependency)
      if dir = @repo.children.find { |c| c.basename.to_s == dependency.name }
        Specification::Set.by_pod_dir(dir)
      end
    end

    def search_by_name(query)
      dirs = @repo.children.select do |child|
        child.basename.to_s.downcase.include?(query.downcase)
      end
      dirs.map { |dir| Specification::Set.by_pod_dir(dir) }
    end
  end
end
