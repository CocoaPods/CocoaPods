module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # A simple container produced after a pod project generation is completed.
        #
        class PodsProjectGeneratorResult
          # @return [Project] project
          #
          attr_reader :project

          # @return [Hash{Project => Array<PodTargets>}] Project by pod targets map
          #
          attr_reader :projects_by_pod_targets

          # @return [InstallationResults] target installation results
          #
          attr_reader :target_installation_results

          # Initialize a new instance
          #
          # @param [Project] project @see #project
          # @param [Hash{Project => Array<PodTargets>}] projects_by_pod_targets @see #projects_by_pod_targets
          # @param [InstallationResults] target_installation_results @see #target_installation_results
          #
          def initialize(project, projects_by_pod_targets, target_installation_results)
            @project = project
            @projects_by_pod_targets = projects_by_pod_targets
            @target_installation_results = target_installation_results
          end
        end
      end
    end
  end
end
