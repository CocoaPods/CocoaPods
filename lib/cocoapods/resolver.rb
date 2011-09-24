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
      specification.dependencies.each do |dependency|
        set = Source.search(dependency)
        set.required_by(specification)
        unless @sets.include?(set)
          @sets << set
          find_dependency_sets(set.specification)
        end
      end
    end
  end
end
