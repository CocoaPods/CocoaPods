module Pod
  class Resolver
    def initialize(specification)
      @specification = specification
    end

    def resolve
      @sets = []
      find_dependency_sets(@specification)
      @sets
    end

    def find_dependency_sets(specification)
      specification.read(:dependencies).each do |dependency|
        sets = Source.search(dependency)
        if sets.empty?
          raise "Unable to find a pod named `#{dependency.name}'"
        end
        sets.each do |set|
          set.required_by(specification, dependency)
          unless @sets.include?(set)
            @sets << set
            find_dependency_sets(set.podspec)
          end
        end
      end
    end
  end
end
