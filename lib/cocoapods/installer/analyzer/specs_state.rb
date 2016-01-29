require 'set'

module Pod
  class Installer
    class Analyzer
      # This class represents the state of a collection of Pods.
      #
      # @note The names of the pods stored by this class are always the **root**
      #       name of the specification.
      #
      # @note The motivation for this class is to ensure that the names of the
      #       subspecs are added instead of the name of the Pods.
      #
      class SpecsState
        # Initialize a new instance
        #
        # @param  [Hash{Symbol=>String}] pods_by_state
        #         The name of the pods grouped by their state
        #         (`:added`, `:removed`, `:changed` or `:unchanged`).
        #
        def initialize(pods_by_state = nil)
          @added     = Set.new
          @deleted   = Set.new
          @changed   = Set.new
          @unchanged = Set.new

          if pods_by_state
            {
              :added => :added,
              :changed => :changed,
              :removed => :deleted,
              :unchanged => :unchanged,
            }.each do |state, spec_state|
              Array(pods_by_state[state]).each do |name|
                add_name(name, spec_state)
              end
            end
          end
        end

        # @return [Set<String>] the names of the pods that were added.
        #
        attr_accessor :added

        # @return [Set<String>] the names of the pods that were changed.
        #
        attr_accessor :changed

        # @return [Set<String>] the names of the pods that were deleted.
        #
        attr_accessor :deleted

        # @return [Set<String>] the names of the pods that were unchanged.
        #
        attr_accessor :unchanged

        # Displays the state of each pod.
        #
        # @return [void]
        #
        def print
          added    .sort.each { |pod| UI.message('A'.green + " #{pod}", '', 2) }
          deleted  .sort.each { |pod| UI.message('R'.red + " #{pod}", '', 2) }
          changed  .sort.each { |pod| UI.message('M'.yellow + " #{pod}", '', 2) }
          unchanged.sort.each { |pod| UI.message('-' + " #{pod}", '', 2) }
        end

        # Adds the name of a Pod to the give state.
        #
        # @param  [String] name
        #         the name of the Pod.
        #
        # @param  [Symbol] state
        #         the state of the Pod.
        #
        # @return [void]
        #
        def add_name(name, state)
          send(state) << Specification.root_name(name)
        end
      end
    end
  end
end
