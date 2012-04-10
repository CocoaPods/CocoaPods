require 'net/http'

module Pod
  class Specification
    class Statistics
      def initialize(set)
        @set = set
        @spec = set.specification.part_of_other_pod? ? set.specification.part_of_specification : set.specification
      end

      def creation_date
        Dir.chdir(@set.pod_dir.dirname) do
          @creation_date ||= Time.at(`git log --format=%ct ./#{@set.name} | tail -1`.to_i)
        end
      end

      def homepage
        @spec.homepage
      end

      def description
        @spec.description
      end

      def summary
        @spec.summary
      end

      def source_url
        @spec.source.reject {|k,_| k == :commit || k == :tag }.values.first
      end

      def github_response
        return @github_response if @github_response
        github_url, username, reponame = *(source_url.match(/[:\/]([\w\-]+)\/([\w\-]+)\.git/).to_a)
        if github_url
          @github_response = Net::HTTP.get('github.com', "/api/v2/json/repos/show/#{username}/#{reponame}")
        end
      end

      def github_watchers
        github_response.match(/\"watchers\"\W*:\W*([0-9]+)/).to_a[1] if github_response
      end

      def github_forks
        github_response.match(/\"forks\"\W*:\W*([0-9]+)/).to_a[1] if github_response
      end
    end
  end
end
