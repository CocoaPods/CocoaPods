module Pod
  class Installer
    class Analyzer

      # Analyzes the user project to return information about the target
      # definitions.
      #
      class UserProjectAnalyzer

        # @return [Array<Podfile::TargetDefinition>] The target definitions
        #         which should be analyzed.
        #
        attr_reader :target_definitions

        # @return [Pathname] The root of the installation.
        #
        attr_reader :installation_root

        # @param [Array<Podfile::TargetDefinition>] target_definitions @see target_definitions
        # @param [Pathname] installation_root @see installation_root
        #
        def initialize(target_definitions, installation_root)
          @target_definitions = target_definitions
          @installation_root = Pathname.new(installation_root)
        end

        # Performs the analysis and returns the computed information.
        #
        # @return [Array<TargetDefinitionIntrospectionData>]
        #
        def analyze
          results = {}
          target_definitions.each do |target_definition|
            result = TargetDefinitionIntrospectionData.new
            result.project_path = user_project_path(target_definition)
            result.project = Xcodeproj::Project.new(result.project_path)
            result.targets = project_targets(target_definition, result.project)
            result.build_configurations = build_configurations(target_definition, result.targets)
            result.platform = platform(target_definition, result.targets)
            results[target_definition] = result
          end
          results
        end

        # Stores the information of a target definition computed analyzing the
        # user project.
        #
        class TargetDefinitionIntrospectionData

          # @return [String] The path of the project.
          #
          attr_accessor :project_path

          # @return [Xcodeproj::Project] The project.
          #
          attr_accessor :project

          # @return [Array<Xcodeproj::Project::NativeTarget>] The list of the
          #         targets the definition should link with.
          #
          attr_accessor :targets

          # @return [Hash{String=>Symbols}] The name of the build
          # configurations and their respective type.
          #
          attr_accessor :build_configurations

          # @return [Platform] The platform of the target definition.
          #
          attr_accessor :platform
        end

        private

        #---------------------------------------------------------------------#

        # @!group Analysis sub-steps

        # Returns the path of the user project that the {TargetDefinition}
        # should integrate.
        #
        # @param  [Podfile::TargetDefinition] target_definition
        #         The target definition.
        #
        # @raise  If the project is implicit and there are multiple projects.
        #
        # @raise  If the path doesn't exits.
        #
        # @return [Pathname] the path of the user project.
        #
        def user_project_path(target_definition)
          if target_definition.user_project_path
            path = normalize_project_path(target_definition.user_project_path, installation_root)
            unless path.exist?
              raise Informative, "Unable to find the Xcode project `#{path}` for the target `#{target_definition.label}`."
            end
          else
            xcodeprojs = Pathname.glob(installation_root + '*.xcodeproj')
            if xcodeprojs.size == 1
              path = xcodeprojs.first
            else
              raise Informative, "Could not automatically select an Xcode project. Specify one in your Podfile like so:\n\n    xcodeproj 'path/to/Project.xcodeproj'\n"
            end
          end
          path
        end

        # Returns a list of the targets from the project of {TargetDefinition}
        # that needs to be integrated.
        #
        # @raise  If a target with the specified name or the one of target
        #         definition doesn't exists.
        #
        # @raise  If no target exits.
        #
        # @param  [Podfile::TargetDefinition] target_definition
        #         The target definition.
        #
        # @param  [Xcodeproj::Project] project
        #         The user project.
        #
        # @return [Array<Xcodeproj::Project::PBXNativeTarget>] The list of the
        #         targets.
        #
        def project_targets(target_definition, project)
          project_targets = native_targets(project)
          if link_with = target_definition.link_with
            targets = project_targets.select { |t| link_with.include?(t.name) }
            raise Informative, "Unable to find the targets named `#{link_with.to_sentence}` to link with target definition `#{target_definition.name}`" if targets.empty?
          elsif target_definition.link_with_first_target?
            targets = [ project_targets.first ].compact
            raise Informative, "Unable to find a target" if targets.empty?
          else
            target = project_targets.find { |t| t.name == target_definition.name.to_s }
            targets = [ target ].compact
            raise Informative, "Unable to find a target named `#{target_definition.name.to_s}`" if targets.empty?
          end
          targets
        end

        # Returns the build configurations for the target definition taking
        # into account the specified ones and the ones of the user project.
        #
        # @param  [Podfile::TargetDefinition] target_definition
        #         The target definition.
        #
        # @param  [Array<Xcodeproj::Project::PBXNativeTarget>] The list of the
        #         targets.
        #
        # @return [Hash{String=>Symbol}] A hash where the keys represent the user build
        #         configuration names and the value the type (`:debug` or
        #         `:release`).
        #
        def build_configurations(target_definition, targets)
          specified_configurations = target_definition.build_configurations || {}
          project_configurations = targets.map { |t| t.build_configurations.map(&:name) }.flatten
          collected_configurations = project_configurations.inject({}) do |hash, name|
            unless name == 'Debug' || name == 'Release'
              hash[name] = :release
            end
            hash
          end
          collected_configurations.merge(specified_configurations)
        end

        # Returns the platform for the given target definition.
        #
        # @param  [Podfile::TargetDefinition] target_definition
        #         The target definition.
        #
        # @param [Array<XcodeProj::Project::NativeTarget>] targets
        #         The list of the native targets that the target definition
        #         should link with.
        #
        # @raise  If the targets have different platform names.
        #
        # @note   If the deployment targets do not match the lowest one is
        #         selected.
        #
        # @return [Platform] The platform.
        #
        def platform(target_definition, targets)
          if target_definition.platform
            return target_definition.platform
          end

          name = nil
          deployment_target = nil
          targets.each do |target|
            name ||= target.platform_name
            raise Informative, "Targets with different platforms" unless name == target.platform_name
            if !deployment_target || deployment_target > Version.new(target.deployment_target)
              deployment_target = Version.new(target.deployment_target)
            end
          end

          Platform.new(name, deployment_target)
        end

        private

        # @!group Helpers

        #---------------------------------------------------------------------#

        # Normalizes the given project path according to the installation root.
        #
        # @param  [String, Pathname] project_path
        #         The path to normalize
        #
        # @param  [String, Pathname] installation_root
        #         The root of the installation
        #
        # @return [Pathname] The absolute path of the project.
        #
        def normalize_project_path(project_path, installation_root)
          installation_root = Pathname.new(installation_root)
          path = installation_root + project_path
          path = "#{path}.xcodeproj" unless File.extname(path) == '.xcodeproj'
          path
        end

        # Returns the native targets of the given project, excluding aggregate
        # targets.
        #
        # @param  [Xcodeproj::Project] project
        #         The project which contains the targets.
        #
        # @return [Array<Xcodeproj::Project::PBXNativeTarget>] The list of the
        #         targets.
        #
        def native_targets(project)
          project.targets.reject do |target|
            target.is_a? Xcodeproj::Project::Object::PBXAggregateTarget
          end
        end

        #---------------------------------------------------------------------#

      end
    end
  end
end
