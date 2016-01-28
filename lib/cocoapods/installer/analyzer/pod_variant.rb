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

        # @return [Specification] the root specification
        #
        def root_spec
          specs.first.root
        end

        # @param [Array<String>] specs       @see #specs
        # @param [Platform] platform         @see #platform
        #
        def initialize(specs, platform)
          self.specs = specs
          self.platform = platform
        end

        # @return [Bool] whether the {PodVariant} is equal to another taking all
        #         all their attributes into account
        #
        def ==(other)
          self.class == other.class &&
            specs == other.specs &&
            platform == other.platform
        end
        alias_method :eql?, :==

        # Hashes the instance by all its attributes.
        #
        # This adds support to make instances usable as Hash keys.
        #
        # @!visibility private
        def hash
          [specs, platform].hash
        end
      end
    end
  end
end
