require 'open-uri'
require 'tempfile'
require 'zlib'
require 'yaml'

module Pod
  class Downloader
    class Http < Downloader
      executable :curl
      executable :unzip
      executable :tar
      
      attr_accessor :filename, :download_path
      def download
        @filename        = filename_with_type type
        @download_path   = target_path + @filename

        download_file @download_path
        extract_with_type @download_path, type
      end

      def type
        options[:type] || type_with_url(url)
      end

      def clean
        FileUtils.rm @download_path
      end

      private
      def type_with_url(url)
        if url =~ /.zip$/
          :zip
        elsif url =~ /.tgz$/
          :tgz
        elsif url =~ /.tar$/
          :tar
        else
          nil
        end
      end
      
      def filename_with_type(type=:zip)
        case type
        when :zip
          "file.zip"
        when :tgz
          "file.tgz"
        when :tar
          "file.tar"
        else
          raise "Pod::Downloader::Http Unsupported file type: #{type}"
        end
      end
      
      def download_file(full_filename)
        curl "-L -o '#{full_filename}' '#{url}'"
      end

      def extract_with_type(full_filename, type=:zip)
        case type
        when :zip
          unzip "'#{full_filename}' -d #{target_path}"
        when :tgz
          tar "xfz '#{full_filename}' -d #{target_path}"
        when :tar
          tar "xf '#{full_filename}' -d #{target_path}"
        else
          raise "Http Downloader: Unsupported file type"
        end
      end

    end
  end
end
