module Pod
  class Downloader
    class Mercurial < Downloader
      executable :hg

      def download
        @pod_root.dirname.mkpath
        if @options[:revision]
          download_revision
        else
          download_head
        end
      end

      def download_head
        hg "clone '#{@url}' '#{@pod_root}'"
      end

      def download_revision
        hg "clone '#{@url}' --rev '#{@options[:revision]}' '#{@pod_root}'"
      end

      def clean(clean_paths = [])
        super
        (@pod_root + '.hg').rmtree
      end
    end
  end
end

