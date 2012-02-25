module Pod
  class Downloader
    class Mercurial < Downloader
      executable :hg

      def download
        if options[:revision]
          download_revision
        else
          download_head
        end
      end

      def download_head
        hg "clone '#{url}' '#{pod.root}'"
      end

      def download_revision
        hg "clone '#{url}' --rev '#{options[:revision]}' '#{pod.root}'"
      end

      def clean(clean_paths = [])
        super
        (pod.root + '.hg').rmtree
      end
    end
  end
end

