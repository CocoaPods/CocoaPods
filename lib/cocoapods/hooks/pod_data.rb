module Pod
  module Hooks

    class Specification
      UI.warn "Specification#config is deprecated. The config is accessible from " \
        "the parameter passed to the hooks"
      include Config::Mixin
    end

    # Stores the information of the Installer for the hooks
    #
    class PodData

      # @return [String]
      #
      def name
        root_spec.name
      end

      # @return [Version]
      #
      def version
        root_spec.name
      end

      # @return [Specification]
      #
      def root_spec
        file_accessors.first.spec.root
      end

      # @return [Array<Specification>]
      #
      def specs
        file_accessors.map(&:spec)
      end

      # @return [Pathname]
      #
      def root
        file_accessors.first.path_list.root
      end

      # @return [Array<Pathname>]
      #
      def source_files
        file_accessors.map(&:source_files).flatten.uniq
      end

      #-----------------------------------------------------------------------#

      # @!group Private implementation

      # @param [Installer] installer @see installer
      #
      def initialize(file_accessors)
        @file_accessors = file_accessors
      end

      def to_s
        root_spec.to_s
      end

      private

      attr_reader :file_accessors

      #-----------------------------------------------------------------------#

    end
  end
end
