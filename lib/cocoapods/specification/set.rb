require 'active_support/core_ext/array/conversions'

module Pod
  class Specification

    # A Specification::Set is resposible of handling all the specifications of
    # a Pod. This class stores the information of the dependencies that reuired
    # a Pod in the resolution process.
    #
    # @note The alpahbetical order of the sets is used to select a specification
    #       if multiple are available for a given version.
    #
    # @note The set class is not and should be not aware of the backing store
    #       of a Source.
    #
    class Set

      # @return [String] The name of the Pod.
      #
      attr_reader :name

      # @return [Array<Source>] The sources that contain the specifications for
      #   the available versions of a Pod.
      #
      attr_reader :sources

      # @param [String] name            The name of the Pod.
      #
      # @param [Array<Source>,Source] sources
      #                                 The sources that contain a Pod.
      #
      def initialize(name, sources)
        @name    = name
        sources  = sources.is_a?(Array) ? sources : [sources]
        @sources = sources.sort_by(&:name)
        @required_by  = []
        @dependencies = []
      end

      # @return [void]                  Stores a dependency on the Pod.
      #
      # @param [Dependency] dependency  A dependency that requires the Pod.
      #
      # @param [String] dependent_name  The name of the owner of the
      #                                 dependency.  It is used only to display
      #                                 the Pod::Informative.
      #
      # @raises If the versions requirement of the dependency are not
      #         compatible with the previously stored dependencies.
      #
      def required_by(dependency, dependent_name)
        unless @required_by.empty? || dependency.requirement.satisfied_by?(Gem::Version.new(required_version.to_s))
          raise Informative, "#{dependent_name} tries to activate `#{dependency}', but already activated version `#{required_version}' by #{@required_by.to_sentence}."
        end
        @specification = nil
        @required_by  << dependent_name
        @dependencies << dependency
      end

      # @return [Dependency] A dependency including all the versions
      #                      requirements of the stored dependencies.
      #
      def dependency
        @dependencies.inject(Dependency.new(name)) do |previous, dependency|
          previous.merge(dependency.to_top_level_spec_dependency)
        end
      end

      # @return [Specification] The specification for the given subspec name,
      #                         from {specification}.
      #
      # @param [String] name    The name of the specification. It can be the
      #                         name of the top level parent or the name of a
      #                         subspec.
      #
      # @see specification
      #
      def specification_by_name(name)
        specification.top_level_parent.subspec_by_name(name)
      end

      # @return [Specification] The top level specification of the Pod for the
      #                         {required_version}.
      #
      # @note If multiple sources have a specification for the
      #       {required_version} The alpahbetical order of their names is used
      #       to disambiguate.
      #
      def specification
        unless @specification
          sources = versions_by_source.select { |_, versions| versions.include?(required_version) }.keys
          source  = sources.sort_by(&:name).first
          @specification = source.specification(name, required_version)
        end
        @specification
      end

      # @return [Version] The highest version that satisfies {dependency}.
      #
      def required_version
        versions.find { |v| dependency.match?(name, v) } ||
          raise(Informative, "Required version (#{dependency}) not found for `#{name}'.\nAvailable versions: #{versions.join(', ')}")
      end

      # @return [Array<Version>] All the available versions for the Pod, sorted
      #                          from highest to lowest.
      #
      def versions
        versions_by_source.values.flatten.uniq.sort.reverse
      end

      # @return [Hash{Source => Version}] All the available versions for the
      #                                   Pod groupped by source.
      #
      def versions_by_source
        result = {}
        sources.each do |source|
          result[source] = source.versions(name)
        end
        result
      end

      def ==(other)
        self.class === other && @name == other.name && @sources.map(&:name) == other.sources.map(&:name)
      end

      def to_s
        "#<#{self.class.name} for `#{name}' with required version `#{required_version}' available at `#{sources.map(&:name) * ', '}'>"
      end
      alias_method :inspect, :to_s

      # The Set::External class handles Pods from external sources. Pods from
      # external sources don't use the {Pod::Sources} and are intialized by a
      # given specification.
      #
      # @note External sources *don't* support subspecs.
      #
      class External < Set
        def initialize(specification)
          @specification = specification
          @required_by   = []
          @dependencies  = []
        end

        def name
          @specification.top_level_parent.name
        end

        def ==(other)
          self.class === other && @specification == other.specification
        end

        def required_by(dependency, dependent_name)
          before = @specification
          super(dependency, dependent_name)
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
