require 'open-uri'
require 'tempfile'
require 'zlib'
require 'digest/sha1'

module Pod
  class Downloader
    class Git < Downloader
      include Config::Mixin
      executable :git

      MAX_CACHE_SIZE = 500

      def download
        create_cache unless cache_exist?
        puts '-> Cloning git repo' if config.verbose?
        if options[:tag]
          download_tag
        elsif options[:branch]
          download_branch
        elsif options[:commit]
          download_commit
        else
          download_head
        end
        removed_cached_repos_if_needed
      end

      def create_cache
        puts "-> Creating cache git repo (#{cache_path})" if config.verbose?
        cache_path.rmtree if cache_path.exist?
        cache_path.mkpath
        clone(url, cache_path)
      end

      def removed_cached_repos_if_needed
        return unless caches_dir.exist?
        Dir.chdir(caches_dir) do
          repos = Pathname.new(caches_dir).children.select { |c| c.directory? }.sort_by(&:ctime)
          while caches_size >= MAX_CACHE_SIZE && !repos.empty?
            dir = repos.shift
            puts '->'.yellow << " Removing git cache for `#{origin_url(dir)}'" if config.verbose?
            dir.rmtree
          end
        end
      end

      def cache_path
        @cache_path ||= caches_dir + "#{Digest::SHA1.hexdigest(url.to_s)}"
      end

      def cache_exist?
        cache_path.exist? && origin_url(cache_path).to_s == url.to_s
      end

      def origin_url(dir)
        Dir.chdir(dir) { `git config remote.origin.url`.chomp }
      end

      def caches_dir
        Pathname.new(File.expand_path("~/Library/Caches/CocoaPods/Git"))
      end

      def clone_url
        cache_path
      end

      def caches_size
        # expressed in Mb
        `du -cm`.split("\n").last.to_i
      end

      def update_cache
        puts "-> Updating cache git repo (#{cache_path})" if config.verbose?
        Dir.chdir(cache_path) do
          git "reset --hard HEAD"
          git "clean -d -x -f"
          git "pull"
        end
      end

      def ref_exists?(ref)
        Dir.chdir(cache_path) { git "rev-list --max-count=1 #{ref}" }
        $? == 0
      end

      def ensure_ref_exists(ref)
        return if ref_exists?(ref)
        # Skip pull if not needed
        update_cache
        raise Informative, "[!] Cache unable to find git reference `#{ref}' for `#{url}'.".red unless ref_exists?(ref)
      end

      def ensure_remote_branch_exists(branch)
        Dir.chdir(cache_path) { git "branch -r | grep #{branch}$" } # check for remote branch and do suffix matching ($ anchor)
        return if $? == 0

        raise Informative, "[!] Cache unable to find git reference `#{branch}' for `#{url}' (#{$?}).".red
      end

      def download_head
        update_cache
        clone(clone_url, target_path)
      end

      def download_tag
        ensure_ref_exists(options[:tag])
        Dir.chdir(target_path) do
          git "init"
          git "remote add origin '#{clone_url}'"
          git "fetch origin tags/#{options[:tag]}"
          git "reset --hard FETCH_HEAD"
          git "checkout -b activated-pod-commit"
        end
      end

      def download_commit
        ensure_ref_exists(options[:commit])
        clone(clone_url, target_path)
        Dir.chdir(target_path) do
          git "checkout -b activated-pod-commit #{options[:commit]}"
        end
      end

      def download_branch
        ensure_remote_branch_exists(options[:branch])
        clone(clone_url, target_path)
        Dir.chdir(target_path) do
          git "remote add upstream '#{@url}'" # we need to add the original url, not the cache url
          git "fetch -q upstream" # refresh the branches
          git "checkout --track -b activated-pod-commit upstream/#{options[:branch]}" # create a new tracking branch
          puts "Just downloaded and checked out branch: #{options[:branch]} from upstream #{clone_url}" if config.verbose?
        end
      end

      def clone(from, to)
        git "clone \"#{from}\" \"#{to}\""
      end
    end

    class GitHub < Git
      def download_head
        download_only? ? download_and_extract_tarball('master') : super
      end

      def download_tag
        download_only? ? download_and_extract_tarball(options[:tag]) : super
      end

      def download_commit
        download_only? ? download_and_extract_tarball(options[:commit]) : super
      end

      def download_branch
        download_only? ? download_and_extract_tarball(options[:branch]) : super
      end

      def tarball_url_for(id)
        original_url, username, reponame = *(url.match(/[:\/]([\w\-]+)\/([\w\-]+)\.git/))
        "https://github.com/#{username}/#{reponame}/tarball/#{id}"
      end

      def tmp_path
        target_path + "tarball.tar.gz"
      end

      private

      def download_only?
        @options[:download_only]
      end

      def download_and_extract_tarball(id)
        File.open(tmp_path, "w+") do |tmpfile|
          open tarball_url_for(id) do |archive|
            tmpfile.write Zlib::GzipReader.new(archive).read
          end

          system "tar xf #{tmpfile.path} -C #{target_path} --strip-components 1"
        end
      end
    end
  end
end
