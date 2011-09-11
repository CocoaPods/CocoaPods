module Pod
  class Resolver
    def initialize(specification)
      @specification = specification
    end

    def resolve
      @sets = []
      find_dependency_sets(@specification)
      #@sets.reject(&:only_part_of_other_pod?).map(&:podspec)
      @sets
    end

    def find_dependency_sets(specification)
      specification.read(:dependencies).each do |dependency|
        sets = Source.search(dependency)
        if sets.empty?
          raise "Unable to find a pod named `#{dependency.name}'"
        end
        sets.each do |set|
          # TODO ultimately this compatibility check should be used to try and
          # resolve the conflicts, but for now we'll keep it simple.
          if existing_set = @sets.find { |s| s == set }
            existing_set.required_by(specification, dependency)
          else
            set.required_by(specification, dependency)
            @sets << set
            find_dependency_sets(set.podspec)
          end
        end
      end
    end
  end
end
