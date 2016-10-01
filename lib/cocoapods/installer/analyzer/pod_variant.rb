module Pod
  class Installer
    class Analyzer
      # Bundles the information needed to setup a {PodTarget}.
      class PodVariant
        # @return [Array<Specification>] the spec and subspecs for the target
        #
        attr_accessor :specs

        # @return [Platform] the platform
        #
        attr_accessor :platform

        # @return [Bool] whether this pod should be built as framework
        #
        attr_accessor :requires_frameworks
        alias_method :requires_frameworks?, :requires_frameworks

        # @return [Specification] the root specification
        #
        def root_spec
          specs.first.root
        end

        # Initialize a new instance from its attributes.
        #
        # @param [Array<String>] specs       @see #specs
        # @param [Platform] platform         @see #platform
        # @param [Bool] requires_frameworks  @see #requires_frameworks?
        #
        def initialize(specs, platform, requires_frameworks = false)
          self.specs = specs
          self.platform = platform
          self.requires_frameworks = requires_frameworks
        end

        # @return [Bool] whether the {PodVariant} is equal to another taking all
        #         all their attributes into account
        #
        def ==(other)
          self.class == other.class &&
            specs == other.specs &&
            platform == other.platform &&
            requires_frameworks == other.requires_frameworks
        end
        alias_method :eql?, :==

        # Hashes the instance by all its attributes.
        #
        # This adds support to make instances usable as Hash keys.
        #
        # @!visibility private
        def hash
          [specs, platform, requires_frameworks].hash
        end
      end
    end
  end
end
