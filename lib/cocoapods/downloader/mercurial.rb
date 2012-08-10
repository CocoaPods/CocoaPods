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
        hg! "clone \"#{url}\" \"#{target_path}\""
      end

      def download_revision
        hg! "clone \"#{url}\" --rev '#{options[:revision]}' \"#{target_path}\""
      end
    end
  end
end

