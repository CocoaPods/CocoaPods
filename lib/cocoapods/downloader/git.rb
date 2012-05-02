require 'open-uri'
require 'tempfile'
require 'zlib'
require 'digest/sha1'

module Pod
  class Downloader
    class Git < Downloader
      executable :git

      def download
        prepare_cache
        if options[:tag]
          download_tag
        elsif options[:commit]
          download_commit
        else
          download_head
        end
      end

      def prepare_cache
        # TODO:clean oldest repos if the cache becomes too big
        if cache_path.exist?
          #TODO: check remote and reset hard
          Dir.chdir(cache_path) { git "pull" }
        else
          FileUtils.mkdir_p cache_path
          Dir.chdir(cache_path) do
            git "clone '#{url}' ."
          end
        end
      end

      def cache_path
        @cache_path ||= Pathname.new "/var/tmp/CocoaPods/Git/#{Digest::SHA1.hexdigest(url.to_s)}/"
      end

      def download_head
        git "clone '#{cache_path}' '#{target_path}'"
      end

      def download_tag
        Dir.chdir(target_path) do
          git "init"
          git "remote add origin '#{cache_path}'"
          git "fetch origin tags/#{options[:tag]}"
          git "reset --hard FETCH_HEAD"
          git "checkout -b activated-pod-commit"
        end
      end

      def download_commit
        git "clone '#{cache_path}' '#{target_path}'"

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
