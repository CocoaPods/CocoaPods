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
        git "clone '#{url}' '#{pod.root}'"
      end

      def download_tag
        pod.chdir do
          git "init"
          git "remote add origin '#{url}'"
          git "fetch origin tags/#{options[:tag]}"
          git "reset --hard FETCH_HEAD"
          git "checkout -b activated-pod-commit"
        end
      end

      def download_commit
        git "clone '#{url}' '#{pod.root}'"
        
        pod.chdir do
          git "checkout -b activated-pod-commit #{options[:commit]}"
        end
      end

      def clean
        (pod.root + '.git').rmtree
      end
    end
  end
end
