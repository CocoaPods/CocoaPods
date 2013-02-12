module Pod
  module Hooks

    # Stores the information of the Installer for the hooks
    #
    class PodData

      # @return [Pathname]
      #
      attr_accessor :root

      # @return [Version]
      #
      attr_accessor :root_spec

      #--------------------------------------------------------------------------------#

      def to_s
        root_spec.to_s
      end

      def source_files
        []
      end

      #--------------------------------------------------------------------------------#

    end
  end
end



# TODO
module Pod
  class Specification
    include Config::Mixin
  end
end

