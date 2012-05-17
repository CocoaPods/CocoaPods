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
          @set.specification
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
          spec.available_platforms.sort { |a,b| a.to_s.downcase <=> b.to_s.downcase }.join(' - ')
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

        def github_last_activity
          distance_from_now_in_words(Pod::Specification::Statistics.instance.github_pushed_at(@set))
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

        def distance_from_now_in_words(from_time)
          return nil unless from_time
          from_time = Time.parse(from_time)
          to_time = Time.now
          distance_in_days = (((to_time - from_time).abs)/60/60/24).round

          case distance_in_days
          when 0..7
            "less than a week ago"
          when 8..29
            "#{distance_in_days} days ago"
          when 30..45
            "1 month ago"
          when 46..365
            "#{(distance_in_days.to_f / 30).round} months ago"
          else
            "more than a year ago"
          end
        end
      end
    end
  end
end

