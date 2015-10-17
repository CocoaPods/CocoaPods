module Pod
  class Installer
    class Analyzer
      class TargetInspectionResult
        # @return [TargetDefinition] the target definition, whose project was
        #         inspected
        #
        attr_accessor :target_definition

        # @return [Pathname] the path of the user project that the
        #         #target_definition should integrate
        #
        attr_accessor :project_path

        # @return [Array<String>] the uuid of the user's targets
        #
        attr_accessor :project_target_uuids

        # @return [Hash{String=>Symbol}] A hash representing the user build
        #         configurations where each key corresponds to the name of a
        #         configuration and its value to its type (`:debug` or
        #         `:release`).
        #
        attr_accessor :build_configurations

        # @return [Platform] the platform of the user targets
        #
        attr_accessor :platform

        # @return [Array<String>] the architectures used by user's targets
        #
        attr_accessor :archs

        # @return [Bool] whether frameworks are recommended for the integration
        #         due to the presence of Swift source in the user's targets
        #
        attr_accessor :recommends_frameworks

        # @return [Xcodeproj::Project] the user's Xcode project
        #
        attr_accessor :project
      end
    end
  end
end
