require 'open-uri'
require 'tempfile'
require 'zlib'

module Pod
  class Downloader
    class Git < Downloader
      executable :git

      def download
        if options[:tag]
          download_tag
        elsif options[:commit]
          download_commit
        else
          download_head
        end
      end

      def download_head
        git "clone '#{url}' '#{target_path}'"
      end

      def download_tag
        Dir.chdir(target_path) do
          git "init"
          git "remote add origin '#{url}'"
          git "fetch origin tags/#{options[:tag]}"
          git "reset --hard FETCH_HEAD"
          git "checkout -b activated-pod-commit"
        end
      end

      def download_commit
        git "clone '#{url}' '#{target_path}'"

        Dir.chdir(target_path) do
          git "checkout -b activated-pod-commit #{options[:commit]}"
        end
      end

      def clean
        (target_path + '.git').rmtree
      end
    end

    class GitHub < Git
      def download_head
        download_only? ? download_and_extract_tarball('master') : super
      end

      def download_tag
        super unless download_only?
        download_only? ? download_and_extract_tarball(options[:tag]) : super
      end

      def download_commit
        super unless download_only?
        download_only? ? download_and_extract_tarball(options[:commit]) : super
      end

      def clean
        if download_only?
          FileUtils.rm_f(tmp_path)
        else
          super
        end
      end

      def tarball_url_for(id)
        original_url, username, reponame = *(url.match(/[:\/]([\w\-]+)\/([\w\-]+)\.git/).to_a)
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
