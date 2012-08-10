module Pod
  class Downloader
    class Subversion < Downloader
      executable :svn

      def download
        svn! %|checkout "#{reference_url}" "#{target_path}"|
      end

      def download_head
        svn! %|checkout "#{trunk_url}" "#{target_path}"|
      end

      def reference_url
        result = url.dup
        result << '/'       << options[:folder] if options[:folder]
        result << '/tags/'  << options[:tag] if options[:tag]
        result << '" -r "'  << options[:revision] if options[:revision]
        result
      end

      def trunk_url
        result = url.dup
        result << '/' << options[:folder] if options[:folder]
        result << '/trunk'
        result
      end
    end
  end
end
