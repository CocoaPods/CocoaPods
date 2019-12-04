module Pod
  module Xcode
    class XCFramework
      class Slice
        # @return [Pathname] the path to the .framework root of this framework slice
        #
        attr_reader :path

        # @return [Array<String>] list of supported architectures
        #
        attr_reader :supported_archs

        # @return [String] the framework identifier
        #
        attr_reader :identifier

        # @return [Platform] the supported platform
        #
        attr_reader :platform

        # @return [Symbol] the platform variant. Either :simulator or nil
        #
        attr_reader :platform_variant

        def initialize(path, identifier, archs, platform, platform_variant = nil)
          @path = path
          @identifier = identifier
          @supported_archs = archs
          @platform = Pod::Platform.new(platform)
          @platform_variant = platform_variant.to_sym unless platform_variant.nil?
        end

        # @return [String] the name of the framework
        #
        def name
          @name ||= File.basename(path, '.framework')
        end

        def simulator_variant?
          @platform_variant == :simulator
        end

        # @return [Pathname] the path to the bundled binary
        #
        def binary_path
          path + name
        end
      end
    end
  end
end
