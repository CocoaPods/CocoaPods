require 'net/http'
require 'yaml'

module Pod
  class Specification
    class Statistics
      include Config::Mixin

      def self.instance
        @instance ||= new
      end

      def self.instance=(instance)
        @instance = instance
      end

      def initialize
        @cache = cache_file.exist? ? YAML::load(cache_file.read) : {}
      end

      def creation_dates(sets)
        creation_dates = {}
        sets.each do |set|
          @cache[set.name] ||= {}
          date = @cache[set.name][:creation_date] ||= compute_creation_date(set)
          creation_dates[set.name] = date
        end
        save_cache_file
        creation_dates
      end

      def github_watchers(set)
        compute_github_stats_if_needed(set)
        @cache[set.name][:github_watchers] if @cache[set.name]
      end

      def github_forks(set)
        compute_github_stats_if_needed(set)
        @cache[set.name][:github_forks] if @cache[set.name]
      end

      private

      def cache_file
        Config.instance.repos_dir + 'statistics.yml'
      end

      def save_cache_file
        File.open(cache_file, 'w') {|f| f.write(YAML::dump(@cache)) }
      end

      def compute_creation_date(set)
        Dir.chdir(set.pod_dir.dirname) do
          Time.at(`git log --first-parent --format=%ct #{set.name}`.split("\n").last.to_i)
        end
      end

      def compute_github_stats_if_needed(set)
        if @cache[set.name] && @cache[set.name][:github_check_date] && @cache[set.name][:github_check_date] > Time.now - 60 * 60 * 24
          return
        end
        spec = set.specification.part_of_other_pod? ? set.specification.part_of_specification : set.specification
        source_url = spec.source.reject {|k,_| k == :commit || k == :tag }.values.first
        github_url, username, reponame = *(source_url.match(/[:\/]([\w\-]+)\/([\w\-]+)\.git/).to_a)
        if github_url
          github_response = Net::HTTP.get('github.com', "/api/v2/json/repos/show/#{username}/#{reponame}")
          watchers = github_response.match(/\"watchers\"\W*:\W*([0-9]+)/).to_a[1]
          forks    = github_response.match(/\"forks\"\W*:\W*([0-9]+)/).to_a[1]
          if (watchers && forks)
            @cache[set.name] ||= {}
            @cache[set.name][:github_watchers] = watchers
            @cache[set.name][:github_forks] = forks
            @cache[set.name][:github_check_date] = Time.now
            save_cache_file
          end
        end
      end
    end
  end
end
