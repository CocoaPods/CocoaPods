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
        set = find_dependency_set(dependency)
        set.required_by(specification)
        unless @sets.include?(set)
          validate_platform!(set)
          @sets << set
          find_dependency_sets(set.specification)
        end
      end
    end

    def find_dependency_set(dependency)
      Source.search(dependency)
    end

    def validate_platform!(set)
      spec = set.specification
      unless spec.platform.nil? || spec.platform == @specification.platform
        raise Informative, "The platform required by the Podfile (:#{@specification.platform}) " \
                           "does not match that of #{spec} (:#{spec.platform})"
      end
    end
  end
end
