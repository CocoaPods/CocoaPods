require 'open-uri'
require 'tempfile'
require 'zlib'
require 'digest/sha1'

module Pod
  class Downloader
    class Git < Downloader
      include Config::Mixin
      executable :git

      def download
        prepare_cache
        puts '->'.green << ' Cloning git repo' if config.verbose?
        if options[:tag]
          download_tag
        elsif options[:commit]
          download_commit
        else
          download_head
        end
        removed_cached_repos_if_needed
      end

      def prepare_cache
        return if config.git_cache_size == 0
        if is_cache_valid?
          puts '->'.green << " Updating cache git repo (#{cache_path})" if config.verbose?
          Dir.chdir(cache_path) do
            git "reset --hard HEAD"
            git "clean -d -x -f"
            git "pull"
          end
        else
          puts '->'.green << " Creating cache git repo (#{cache_path})" if config.verbose?
          cache_path.rmtree if cache_path.exist?
          cache_path.mkpath
          git "clone '#{url}' #{cache_path}"
        end
      end

      def removed_cached_repos_if_needed
        return unless caches_dir.exist?
        Dir.chdir(caches_dir) do
          repos = Pathname.new(caches_dir).children.select { |c| c.directory? }.sort_by(&:ctime)
          while caches_size >= config.git_cache_size && !repos.empty?
            dir = repos.shift
            puts '->'.yellow << " Removing git cache for `#{origin_url(dir)}'" if config.verbose?
            dir.rmtree
          end
        end
      end

      def cache_path
        @cache_path ||= caches_dir + "#{Digest::SHA1.hexdigest(url.to_s)}"
      end

      def is_cache_valid?
        cache_path.exist? && origin_url(cache_path) == url
      end

      def origin_url(dir)
        Dir.chdir(dir) { `git config remote.origin.url`.chomp }
      end

      def caches_dir
        Pathname.new "/var/tmp/CocoaPods/Git"
      end

      def clone_url
        # git_cache_size = 0 disables the cache
        config.git_cache_size == 0 ? url : cache_path
      end

      def caches_size
        # expressed in Mb
        `du -cm`.split("\n").last.to_i
      end

      def download_head
        git "clone '#{clone_url}' '#{target_path}'"
      end

      def download_tag
        Dir.chdir(target_path) do
          git "init"
          git "remote add origin '#{clone_url}'"
          git "fetch origin tags/#{options[:tag]}"
          git "reset --hard FETCH_HEAD"
          git "checkout -b activated-pod-commit"
        end
      end

      def download_commit
        git "clone '#{clone_url}' '#{target_path}'"

        Dir.chdir(target_path) do
          git "checkout -b activated-pod-commit #{options[:commit]}"
        end
      end

      def clean
        (target_path + '.git').rmtree
      end
    end
  end
end
