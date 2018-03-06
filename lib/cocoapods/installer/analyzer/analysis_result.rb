module Pod
  class Installer
    class Analyzer
      class AnalysisResult
        # @return [SpecsState] the states of the Podfile specs.
        #
        attr_accessor :podfile_state

        # @return [Hash{TargetDefinition => Array<Specification>}] the
        #         specifications grouped by target.
        #
        attr_accessor :specs_by_target

        # @return [Hash{Source => Array<Specification>}] the
        #         specifications grouped by spec repo source.
        #
        attr_accessor :specs_by_source

        # @return [Array<Specification>] the specifications of the resolved
        #         version of Pods that should be installed.
        #
        attr_accessor :specifications

        # @return [SpecsState] the states of the {Sandbox} respect the resolved
        #         specifications.
        #
        attr_accessor :sandbox_state

        # @return [Array<AggregateTarget>] The aggregate targets created for each
        #         {TargetDefinition} from the {Podfile}.
        #
        attr_accessor :targets

        # @return [Hash{TargetDefinition => Array<TargetInspectionResult>}] the
        #         results of inspecting the user targets
        #
        attr_accessor :target_inspections

        # @return [PodfileDependencyCache] the cache of all dependencies in the
        #         podfile.
        #
        attr_accessor :podfile_dependency_cache

        # @return [Hash{String=>Symbol}] A hash representing all the user build
        #         configurations across all integration targets. Each key
        #         corresponds to the name of a configuration and its value to
        #         its type (`:debug` or `:release`).
        #
        def all_user_build_configurations
          targets.reduce({}) do |result, target|
            result.merge(target.user_build_configurations)
          end
        end
      end
    end
  end
end
