module Pod
  class Downloader
    class Subversion < Downloader
      executable :svn

      def download
        if options[:revision]
          download_revision
        elsif options[:tag]
          download_tag
        else
          download_head
        end
      end

      def download_head
        svn %|checkout "#{url}/#{options[:folder]}" "#{target_path}"|
      end

      def download_revision
        svn %|checkout "#{url}/#{options[:folder]}" -r "#{options[:revision]}" "#{target_path}"|
      end

      def download_tag
        svn %|checkout "#{url}/tags/#{options[:tag]}/#{options[:folder]}" "#{target_path}"|
      end
    end
  end
end
