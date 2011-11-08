module Pod
  class Specification
    class Set
      def self.sets
        @sets ||= {}
      end

      def self.by_specification_name(name)
        sets[name]
      end

      # This keeps an identity map of sets so that you always get the same Set
      # instance for the same pod directory.
      def self.by_pod_dir(pod_dir)
        set = new(pod_dir)
        sets[set.name] ||= set
        sets[set.name]
      end

      attr_reader :pod_dir

      def initialize(pod_dir)
        @pod_dir = pod_dir
        @required_by = []
      end

      def required_by(specification)
        dependency = specification.dependency_by_name(name)
        unless @required_by.empty? || dependency.requirement.satisfied_by?(required_version)
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
          previous.merge(spec.dependency_by_name(name))
        end
      end

      def only_part_of_other_pod?
        @required_by.all? { |spec| spec.dependency_by_name(name).only_part_of_other_pod? }
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
          raise(Informative, "Required version (#{dependency}) not found for `#{name}'.")
      end

      def ==(other)
        self.class === other && @pod_dir == other.pod_dir
      end

      def to_s
        "#<#{self.class.name} for `#{name}' with required version `#{required_version}'>"
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

        def required_by(specification)
          before = @specification
          super(specification)
        ensure
          @specification = before
        end

        def only_part_of_other_pod?
          false
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
