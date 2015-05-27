module Pod
  class Specification
    def config
      UI.warn "[#{name}] Specification#config is deprecated. The config is accessible from " \
        'the parameter passed to the hooks'
      Config.instance
    end
  end

  module Hooks
    # Stores the information of the Installer for the hooks
    #
    class PodRepresentation
      # @return [String] the name of the pod
      #
      attr_accessor :name

      # @return [Version] the version
      #
      def version
        root_spec.version
      end

      # @return [Specification] the root spec
      #
      def root_spec
        file_accessors.first.spec.root
      end

      # @return [Array<Specification>] the specs
      #
      def specs
        file_accessors.map(&:spec).uniq
      end

      # @return [Pathname] the root path
      #
      def root
        file_accessors.first.path_list.root
      end

      # @return [Array<Pathname>] the source files
      #
      def source_files
        file_accessors.map(&:source_files).flatten.uniq
      end

      #-----------------------------------------------------------------------#

      # @!group Private implementation

      # @param [Installer] installer @see installer
      #
      def initialize(name, file_accessors)
        @name = name
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
