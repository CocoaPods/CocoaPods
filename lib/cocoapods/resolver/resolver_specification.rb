module Pod
  class Resolver
    # A small container that wraps a resolved specification for a given target definition. Additional metadata
    # is included here such as if the specification is only used by tests.
    #
    class ResolverSpecification
      # @return [Specification] the specification that was resolved
      #
      attr_reader :spec

      # @return [Source] the spec repo source the specification came from
      #
      attr_reader :source

      # @return [Bool] whether this resolved specification is by non-library targets.
      #
      attr_reader :used_by_non_library_targets_only
      alias used_by_non_library_targets_only? used_by_non_library_targets_only

      # @return [Bool] whether this resolved specification is a transitive dependency that was not directly included
      #         by the target that depends on it
      #
      attr_reader :transitive
      alias :transitive? transitive

      # @return [Array<Specification>] specifications which depend on this specification
      #
      attr_reader :dependent_specs

      # @param [Pod::Specification] @see #spec
      # @param [Boolean] used_by_non_library_targets_only @see #used_by_non_library_targets_only
      # @param [Pod::Source] source @see #source
      # @param [Array<Specification>] dependent_specifications @see #dependent_specifications
      # @param [Boolean] transitive @see #transitive
      #
      def initialize(spec, used_by_non_library_targets_only, source, dependent_specs, transitive)
        @spec = spec
        @used_by_non_library_targets_only = used_by_non_library_targets_only
        @source = source
        @dependent_specs = dependent_specs
        @transitive = transitive
      end

      def name
        spec.name
      end

      def root
        spec.root
      end

      def ==(other)
        self.class == other.class &&
            spec == other.spec &&
            used_by_non_library_targets_only? == other.used_by_non_library_targets_only?
      end
    end
  end
end
