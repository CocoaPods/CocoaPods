module Pod
  class Downloader
    class Subversion < Downloader
      executable :svn

      def download
        if options[:revision]
          download_revision
        else
          download_head
        end
      end

      def download_head
        svn "checkout '#{url}' '#{pod_root}'"
      end

      def download_revision
        svn "checkout '#{url}' -r '#{options[:revision]}' '#{pod.root}'"
      end

      def clean
        pod.root.glob('**/.svn').each(&:rmtree)
      end
    end
  end
end
