module Pod
  class Specification
    class Set
      attr_reader :pod_dir

      def initialize(pod_dir)
        @pod_dir = pod_dir
        @required_by = []
      end

      def required_by(specification)
        dependency = specification.dependency_by_top_level_spec_name(name)
        # TODO we don’t actually do anything in our Version subclass. Maybe we should just remove that.
        unless @required_by.empty? || dependency.requirement.satisfied_by?(Gem::Version.new(required_version.to_s))
          # TODO add graph that shows which dependencies led to this.
          raise Informative, "#{specification} tries to activate `#{dependency}', " \
                             "but already activated version `#{required_version}' " \
                             "by #{@required_by.join(', ')}."
        end
        @specification = nil
        @required_by << specification
      end

      def dependency
        @required_by.inject(Dependency.new(name)) do |previous, spec|
          previous.merge(spec.dependency_by_top_level_spec_name(name).to_top_level_spec_dependency)
        end
      end

      def name
        @pod_dir.basename.to_s
      end

      def specification_path
        @pod_dir + required_version.to_s + "#{name}.podspec"
      end

      def specification
        @specification ||= Specification.from_file(specification_path)
      end

      # Return the first version that matches the current dependency.
      def required_version
        versions.find { |v| dependency.match?(name, v) } ||
          raise(Informative, "Required version (#{dependency}) not found for `#{name}'.\nAvailable versions: #{versions.join(', ')}")
      end

      def ==(other)
        self.class === other && @pod_dir == other.pod_dir
      end

      def to_s
        "#<#{self.class.name} for `#{name}' with required version `#{required_version}' at `#{@pod_dir}'>"
      end
      alias_method :inspect, :to_s

      # Returns Pod::Version instances, for each version directory, sorted from
      # highest version to lowest.
      def versions
        @pod_dir.children.map do |v|
          basename = v.basename.to_s
          Version.new(basename) if v.directory? && basename[0,1] != '.'
        end.compact.sort.reverse
      end

      class External < Set
        def initialize(specification)
          @specification = specification
          @required_by = []
        end

        def name
          @specification.name
        end

        def ==(other)
          self.class === other && name == other.name
        end

        def required_by(specification)
          before = @specification
          super(specification)
        ensure
          @specification = before
        end

        def specification_path
          raise "specification_path"
        end

        def specification
          @specification
        end

        def versions
          [@specification.version]
        end
      end
    end
  end
end
