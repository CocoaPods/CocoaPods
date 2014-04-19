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
        UI.titled_section(title, { :verbose_prefix => "-> " }) do
          require 'openssl'
          OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ssl_version] = 'SSLv3' if OpenSSL::OPENSSL_VERSION == 'OpenSSL 0.9.8y 5 Feb 2013'
          require 'open-uri'
          open(podspec_uri) { |io| store_podspec(sandbox, io.read) }
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
