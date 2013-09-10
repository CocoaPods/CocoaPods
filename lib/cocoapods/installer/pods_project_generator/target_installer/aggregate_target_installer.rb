module Pod
  class Installer
    class PodsProjectGenerator

      # Creates the targets which aggregate the Pods libraries in the Pods
      # project and the relative support files.
      #
      class AggregateTargetInstaller < TargetInstaller

        # Creates the target in the Pods project and the relative support files.
        #
        # @return [void]
        #
        def install!
          UI.message "- Installing target `#{target.name}` #{target.platform}" do
            add_target
          end
        end
      end
    end
  end
end
