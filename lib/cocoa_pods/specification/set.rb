module Pod
  class Specification
    class Set
      def initialize(pod_dir)
        @pod_dir = pod_dir
      end

      def add_dependency(dependency)
        @dependency = dependency
      end

      def name
        @pod_dir.basename.to_s
      end

      def spec_pathname
        @pod_dir + required_version.to_s + "#{name}.podspec"
      end

      def podspec
        Specification.from_podspec(spec_pathname)
      end

      # Return the first version that matches the current dependency.
      def required_version
        unless v = versions.find { |v| @dependency.match?(name, v) }
          raise "Required version (#{@dependency}) not found for `#{name}'."
        end
        v
      end

      def to_s
        "#<#{self.class.name} for `#{name}' with required version `#{required_version}'>"
      end
      alias_method :inspect, :to_s

      private

      # Returns Pod::Version instances, for each version directory, sorted from
      # lowest version to highest.
      def versions
        @pod_dir.children.map { |v| Version.new(v.basename) }.sort
      end
    end
  end
end
