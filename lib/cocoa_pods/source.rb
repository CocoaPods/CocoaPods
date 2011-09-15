module Pod
  class Source
    def self.all
      @sources ||= Config.instance.repos_dir.children.map { |repo| new(repo) }
    end

    def self.search(dependency)
      all.map { |source| source.search(dependency) }.compact.first ||
        raise("Unable to find a pod named `#{dependency.name}'")
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
  end
end
