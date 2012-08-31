module Pod
  class Downloader
    class Subversion < Downloader
      executable :svn

      def initialize(target_path, url, options)
        @target_path, @url, @options = target_path, url, options
      end

      def download
        ui_title(' > Exporting subversion repo', '', 3) do
          svn! %|export "#{reference_url}" "#{target_path}"|
        end
      end

      def download_head
        ui_title(' > Exporting subversion repo', '', 3) do
          svn! %|export "#{trunk_url}" "#{target_path}"|
        end
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
