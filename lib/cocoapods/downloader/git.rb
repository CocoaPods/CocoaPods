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
  end
end
