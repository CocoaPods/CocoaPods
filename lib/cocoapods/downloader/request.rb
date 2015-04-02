module Pod
  module Downloader
    class Request
      attr_reader :released_pod
      alias_method :released_pod?, :released_pod

      attr_reader :spec

      attr_reader :head
      alias_method :head?, :head

      attr_reader :params

      attr_reader :name

      def initialize(spec: nil, released: false, name: nil, version: nil, params: false, head: false)
        @released_pod = released
        @spec = spec
        @params = spec ? spec.source.dup : params
        @name = spec ? spec.name : name
        @head = head

        validate!
      end

      def slug
        if released_pod?
          "Release/#{name}/#{spec.version}"
        else
          opts = params.to_a.sort_by(&:first).map { |k, v| "#{k}=#{v}" }.join('-').gsub(/#{Regexp.escape File::SEPARATOR}+/, '+')
          "External/#{name}/#{opts}"
        end
      end

      private

      def validate!
        raise ArgumentError, 'Requires a name' unless name
        raise ArgumentError, 'Requires a version if released' if released_pod? && !spec.version
        raise ArgumentError, 'Requires params' unless params
        raise ArgumentError, 'Must give a spec for a released download request' if released_pod? && !spec
      end
    end
  end
end
