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
        svn "checkout '#{url}' '#{target_path}'"
      end

      def download_revision
        svn "checkout '#{url}' -r '#{options[:revision]}' '#{target_path}'"
      end

      def clean
        target_path.glob('**/.svn').each(&:rmtree)
      end
    end
  end
end
