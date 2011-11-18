module Pod
  class Downloader
    class Subversion < Downloader
      executable :svn

      def download
        @pod_root.dirname.mkpath
        if @options[:revision]
          download_revision
        else
          download_head
        end
      end

      def download_head
        svn "checkout '#{@url}' '#{@pod_root}'"
      end

      def download_revision
        svn "checkout '#{@url}' -r '#{@options[:revision]}' '#{@pod_root}'"
      end

      def clean(clean_paths = [])
        super
        @pod_root.glob('**/.svn').each(&:rmtree)
      end
    end
  end
end
