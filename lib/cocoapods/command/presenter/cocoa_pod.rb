module Pod
  class Command
    class Presenter
      class CocoaPod
        def initialize(set)
          @set = set
        end

        def spec
          @spec ||= @set.specification.part_of_other_pod? ? @set.specification.part_of_specification : @set.specification
        end

        def name
          @set.name
        end

        def version
          @set.versions.last
        end

        def versions
          @set.versions.reverse.join(", ")
        end

        def homepage
          spec.homepage
        end

        def description
          spec.description
        end

        def summary
          spec.summary
        end

        def source_url
          spec.source.reject {|k,_| k == :commit || k == :tag }.values.first
        end

        def platform
          spec.platform.to_s
        end

        def license
          spec.license[:type] if spec.license
        end

        def creation_date
          Pod::Specification::Statistics.instance.creation_date(@set)
        end

        def github_watchers
          Pod::Specification::Statistics.instance.github_watchers(@set)
        end

        def github_forks
          Pod::Specification::Statistics.instance.github_watchers(@set)
        end
      end
    end
  end
end
