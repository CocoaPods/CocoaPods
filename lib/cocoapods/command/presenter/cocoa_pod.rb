module Pod
  class Command
    class Presenter
      class CocoaPod
        attr_accessor :set

        def initialize(set)
          @set = set
        end

        # set information
        def name
          @set.name
        end

        def version
          @set.versions.last
        end

        def versions
          @set.versions.reverse.join(", ")
        end

        # specification information
        def spec
          @spec ||= @set.specification.part_of_other_pod? ? @set.specification.part_of_specification : @set.specification
        end

        def authors
          oxfordify spec.authors.keys
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

        # will return array of all subspecs (recursevly) or nil
        def subspecs
          (spec.recursive_subspecs.any? && spec.recursive_subspecs) || nil
        end

        # Statistics information
        def creation_date
          Pod::Specification::Statistics.instance.creation_date(@set)
        end

        def github_watchers
          Pod::Specification::Statistics.instance.github_watchers(@set)
        end

        def github_forks
          Pod::Specification::Statistics.instance.github_forks(@set)
        end

        def ==(other)
          self.class === other && @set == other.set
        end

        def eql?(other)
         self.class === other && name.eql?(other.name)
        end

        def hash
          name.hash
        end

        private
        def oxfordify words
          if words.size < 3
            words.join ' and '
          else
            "#{words[0..-2].join(', ')}, and #{words.last}"
          end
        end
      end
    end
  end
end

