module Pod
  module Downloader
    # This class represents a download request for a given Pod.
    #
    class Request
      # @return [Specification,Nil] The specification for the pod whose download
      #         is being requested.
      #
      attr_reader :spec

      # @return [Boolean] Whether this download request is for a released pod.
      #
      attr_reader :released_pod
      alias_method :released_pod?, :released_pod

      # @return [String] The name of the pod whose dowload is being requested.
      #
      attr_reader :name

      # @return [Hash<Symbol, String>] The download parameters for this request.
      #
      attr_reader :params

      # @return [Boolean] Whether the download request is for a head download.
      #
      attr_reader :head
      alias_method :head?, :head


      # @param  [Specification,Nil] spec
      #         see {#spec}
      #
      # @param  [Boolean] released
      #         see {#released_pod}
      #
      # @param  [String,Nil] name
      #         see {#name}
      #
      # @param  [Hash<Symbol,String>,Nil] params
      #         see {#params}
      #
      # @param  [Boolean] head
      #         see {#head}
      #
      def initialize(spec: nil, released: false, name: nil, params: false, head: false)
        @released_pod = released
        @spec = spec
        @params = spec ? spec.source.dup : params
        @name = spec ? spec.name : name
        @head = head

        validate!
      end

      # @param  [String] name
      #         the name of the pod being downloaded.
      #
      # @param  [Hash<#to_s, #to_s>] params
      #         the download parameters of the pod being downloaded.
      #
      # @return [String] The slug used to store the files resulting from this
      #         download request.
      #
      def slug(name: self.name, params: self.params)
        if released_pod?
          checksum = spec.checksum &&  '-' << spec.checksum.limit(5)
          "Release/#{name}/#{spec.version}#{checksum}"
        else
          opts = params.to_a.sort_by(&:first).map { |k, v| "#{k}=#{v}" }.join('-').gsub(/(#{Regexp.escape File::SEPARATOR})+/, '+')
          "External/#{name}/#{opts}"
        end
      end

      private

      # Validates that the given request is well-formed.
      #
      # @return [Void]
      #
      def validate!
        raise ArgumentError, 'Requires a name' unless name
        raise ArgumentError, 'Requires a version if released' if released_pod? && !spec.version
        raise ArgumentError, 'Requires params' unless params
        raise ArgumentError, 'Must give a spec for a released download request' if released_pod? && !spec
      end
    end
  end
end
