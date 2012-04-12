require 'net/https'
require 'uri'
require 'yaml'

module Pod
  class Specification
    class Statistics

      def self.instance
        @instance ||= new
      end

      def self.instance=(instance)
        @instance = instance
      end

      attr_accessor :cache_file, :cache_expiration

      def initialize
        @cache_file = Config.instance.repos_dir + 'statistics.yml'
        @cache_expiration = 60 * 60 * 24 * 3
      end

      def creation_date(set)
        compute_creation_date(set)
      end

      def creation_dates(sets)
        dates = {}
        sets.each { |set| dates[set.name] = compute_creation_date(set, false) }
        save_cache
        dates
      end

      def github_watchers(set)
        github_stats_if_needed(set)
        get_value(set, :gh_watchers)
      end

      def github_forks(set)
        github_stats_if_needed(set)
        get_value(set, :gh_forks)
      end

      private

      def cache
        @cache ||= cache_file && cache_file.exist? ? YAML::load(cache_file.read) : {}
      end

      def get_value(set, key)
        if cache[set.name] && cache[set.name][key]
          cache[set.name][key]
        end
      end

      def set_value(set, key, value)
          cache[set.name] ||= {}
          cache[set.name][key] = value
      end

      def save_cache
        File.open(cache_file, 'w') { |f| f.write(YAML::dump(cache)) } if cache_file
      end

      def compute_creation_date(set, save = true)
        date = get_value(set, :creation_date)
        unless date
          Dir.chdir(set.pod_dir.dirname) do
            date = Time.at(`git log --first-parent --format=%ct #{set.name}`.split("\n").last.to_i)
          end
          set_value(set, :creation_date, date)
        end
        save_cache if save
        date
      end

      def github_stats_if_needed(set)
        return if get_value(set, :gh_date) && get_value(set, :gh_date) > Time.now - cache_expiration
        spec  = set.specification.part_of_other_pod? ? set.specification.part_of_specification : set.specification
        url   = spec.source.reject {|k,_| k == :commit || k == :tag }.values.first
        gh_url, username, reponame = *(url.match(/[:\/]([\w\-]+)\/([\w\-]+)\.git/).to_a)

        return unless gh_url
        response_body = fetch_stats(username, reponame)

        return unless response_body
        watchers  = response_body.match(/"watchers"\W*:\W*([0-9]+)/).to_a[1]
        forks     = response_body.match(/"forks"\W*:\W*([0-9]+)/).to_a[1]

        return unless watchers && forks
        cache[set.name] ||= {}
        set_value(set, :gh_watchers,  watchers)
        set_value(set, :gh_forks,     forks)
        set_value(set, :gh_date,      Time.now)
        save_cache
      end

      def fetch_stats(username, reponame)
        uri               = URI.parse("https://api.github.com/repos/#{username}/#{reponame}")
        http              = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = true
        http.verify_mode  = OpenSSL::SSL::VERIFY_NONE
        request           = Net::HTTP::Get.new(uri.request_uri)
        response          = http.request(request)
        response.body if response.is_a?(Net::HTTPSuccess)
      end
    end
  end
end
