module Pod
  module ExternalSources
    # Provides support for fetching a specification file from an URL. Can be
    # http, file, etc.
    #
    class PodspecSource < AbstractExternalSource
      # @see AbstractExternalSource#fetch
      #
      def fetch(sandbox)
        title = "Fetching podspec for `#{name}` #{description}"
        UI.titled_section(title,  :verbose_prefix => '-> ') do
          is_json = podspec_uri.split('.').last == 'json'
          require 'open-uri'
          open(podspec_uri) { |io| store_podspec(sandbox, io.read, is_json) }
        end
      end

      # @see AbstractExternalSource#description
      #
      def description
        "from `#{params[:podspec]}`"
      end

      private

      # @!group Helpers

      # @return [String] The uri of the podspec appending the name of the file
      #         and expanding it if necessary.
      #
      # @note   If the declared path is expanded only if the represents a path
      #         relative to the file system.
      #
      def podspec_uri
        declared_path = params[:podspec].to_s
        if declared_path.match(%r{^.+://})
          declared_path
        else
          normalized_podspec_path(declared_path)
        end
      end
    end
  end
end
