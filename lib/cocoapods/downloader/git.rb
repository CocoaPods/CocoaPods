require 'open-uri'
# require 'tempfile'
require 'zlib'
require 'digest/sha1'

module Pod
  class Downloader

    # Concreted Downloader class that provides support for specifications with
    # git sources.
    #
    class Git < Downloader
      include Config::Mixin

      executable :git

      def download
        create_cache unless cache_exist?
        UI.section(' > Cloning git repo', '', 1) do
          if options[:tag]
            download_tag
          elsif options[:branch]
            download_branch
          elsif options[:commit]
            download_commit
          else
            download_head
          end
          Dir.chdir(target_path) { git! "submodule update --init"  } if options[:submodules]
        end
        prune_cache
      end


      # @!group Download implementations

      # @return [Pathname] The clone URL, which resolves to the cache path.
      #
      def clone_url
        cache_path
      end

      # @return [void] Convenience method to perform clones operations.
      #
      def clone(from, to)
        UI.section(" > Cloning to Pods folder",'',1) do
          git! %Q|clone "#{from}" "#{to}"|
        end
      end

      # @return [void] Checkouts the HEAD of the git source in the destination
      # path.
      #
      def download_head
        if cache_exist?
          update_cache
        else
          create_cache
        end

        clone(clone_url, target_path)
        Dir.chdir(target_path) { git! "submodule update --init"  } if options[:submodules]
      end

      # @return [void] Checkouts a specific tag of the git source in the
      # destination path.
      #
      def download_tag
        ensure_ref_exists(options[:tag])
        Dir.chdir(target_path) do
          git! "init"
          git! "remote add origin '#{clone_url}'"
          git! "fetch origin tags/#{options[:tag]}"
          git! "reset --hard FETCH_HEAD"
          git! "checkout -b activated-pod-commit"
        end
      end

      # @return [void] Checkouts a specific commit of the git source in the
      # destination path.
      #
      def download_commit
        ensure_ref_exists(options[:commit])
        clone(clone_url, target_path)
        Dir.chdir(target_path) do
          git! "checkout -b activated-pod-commit #{options[:commit]}"
        end
      end

      # @return [void] Checkouts the HEAD of a specific branch of the git
      # source in the destination path.
      #
      def download_branch
        ensure_remote_branch_exists(options[:branch])
        clone(clone_url, target_path)
        Dir.chdir(target_path) do
          git! "remote add upstream '#{@url}'" # we need to add the original url, not the cache url
          git! "fetch -q upstream" # refresh the branches
          git! "checkout --track -b activated-pod-commit upstream/#{options[:branch]}" # create a new tracking branch
          UI.message("Just downloaded and checked out branch: #{options[:branch]} from upstream #{clone_url}")
        end
      end



      # @!group Checking references

      # @return [Bool] Wether a reference (commit SHA or tag)
      #
      def ref_exists?(ref)
        Dir.chdir(cache_path) { git "rev-list --max-count=1 #{ref}" }
        $? == 0
      end

      # @return [void] Checks if a reference exists in the cache and updates
      # only if necessary.
      #
      # @raises if after the update the reference can't be found.
      #
      def ensure_ref_exists(ref)
        return if ref_exists?(ref)
        update_cache
        raise Informative, "[!] Cache unable to find git reference `#{ref}' for `#{url}'.".red unless ref_exists?(ref)
      end

      # @return [Bool] Wether a branch exists in the cache.
      #
      def branch_exists?(branch)
        Dir.chdir(cache_path) { git "branch --all | grep #{branch}$" } # check for remote branch and do suffix matching ($ anchor)
        $? == 0
      end

      # @return [void] Checks if a branch exists in the cache and updates
      # only if necessary.
      #
      # @raises if after the update the branch can't be found.
      #
      def ensure_remote_branch_exists(branch)
        return if branch_exists?(branch)
        update_cache
        raise Informative, "[!] Cache unable to find git reference `#{branch}' for `#{url}' (#{$?}).".red unless branch_exists?(branch)
      end


      # @!group Cache

      # The maximum allowed size for the cache expressed in Mb.
      #
      MAX_CACHE_SIZE = 500

      # @return [Pathname] The directory where the cache for the current git
      # repo is stored.
      #
      # @note The name of the directory is the SHA1 hash value of the URL of
      #       the git repo.
      #
      def cache_path
        @cache_path ||= caches_root + "#{Digest::SHA1.hexdigest(url.to_s)}"
      end

      # @return [Pathname] The directory where the git caches are stored.
      #
      def caches_root
        Pathname.new(File.expand_path("~/Library/Caches/CocoaPods/Git"))
      end

      # @return [Integer] The global size of the git cache expressed in Mb.
      #
      def caches_size
        `du -cm`.split("\n").last.to_i
      end

      # @return [Bool] Wether the cache exits.
      #
      # @note The previous implementation of the cache didn't use a barebone
      #       git repo. This method takes into account this fact and checks
      #       that the cache is actually a barebone repo. If the cache was not
      #       barebone it will be deleted and recreated.
      #
      def cache_exist?
        cache_path.exist? &&
          cache_origin_url(cache_path).to_s == url.to_s &&
          Dir.chdir(cache_path) { git("config core.bare").chomp == "true" }
      end

      # @return [String] The origin URL of the cache with the given directory.
      #
      # @param [String] dir The directory of the cache.
      #
      def cache_origin_url(dir)
        Dir.chdir(dir) { `git config remote.origin.url`.chomp }
      end

      # @return [void] Creates the barebone repo that will serve as the cache
      # for the current repo.
      #
      def create_cache
        UI.section(" > Creating cache git repo (#{cache_path})",'',1) do
          cache_path.rmtree if cache_path.exist?
          cache_path.mkpath
          git! %Q|clone  --mirror "#{url}" "#{cache_path}"|
        end
      end

      # @return [void] Updates the barebone repo used as a cache against its
      # remote.
      #
      def update_cache
        UI.section(" > Updating cache git repo (#{cache_path})",'',1) do
          Dir.chdir(cache_path) { git! "remote update" }
        end
      end

      # @return [void] Deletes the oldest caches until they the global size is
      # below the maximum allowed.
      #
      def prune_cache
        return unless caches_root.exist?
        Dir.chdir(caches_root) do
          repos = Pathname.new(caches_root).children.select { |c| c.directory? }.sort_by(&:ctime)
          while caches_size >= MAX_CACHE_SIZE && !repos.empty?
            dir = repos.shift
            UI.message "#{'->'.yellow} Removing git cache for `#{cache_origin_url(dir)}'"
            dir.rmtree
          end
        end
      end
    end

    # This class allows to download tarballs from GitHub and is not currently
    # being used by CocoaPods as the git cache is preferable.
    #
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
