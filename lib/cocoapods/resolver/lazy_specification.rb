module Pod
  class Specification::Set
    class LazySpecification < BasicObject
      attr_reader :name, :version, :source

      def initialize(name, version, source)
        @name = name
        @version = version
        @source = source
      end

      def method_missing(method, *args, &block)
        specification.send(method, *args, &block)
      end

      def subspec_by_name(name = nil)
        if !name || name == self.name
          self
        else
          specification.subspec_by_name(name)
        end
      end

      def specification
        @specification ||= source.specification(name, version)
      end
    end

    class External
      def all_specifications
        [specification]
      end
    end

    def all_specifications
      @all_specifications ||= versions_by_source.map do |source, versions|
        versions.map { |version| LazySpecification.new(name, version, source) }
      end.flatten
    end
  end
end
