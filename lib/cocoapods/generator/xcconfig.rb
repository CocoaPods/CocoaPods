module Pod
  module Generator

    # Generates an xcconfig file for each target of the Pods project. The
    # configuration file should be used by the user target as well.
    #
    class XCConfig

      # @return [Sandbox] the sandbox where the Pods project is installed.
      #
      attr_reader :sandbox

      # @return [Array<LocalPod>] the list of LocalPods for the library.
      #
      attr_reader :pods

      # @return [String] the relative path of the Pods root respect the user
      #         project that should be integrated by this library.
      #
      attr_reader :relative_pods_root

      # @param  [Platform] platform @see platform
      #
      # @param  [Array<LocalPod>]   @see pods
      #
      def initialize(sandbox, pods, relative_pods_root)
        @sandbox = sandbox
        @pods    = pods
        @relative_pods_root = relative_pods_root
      end

      # @return [Bool] whether the Podfile specifies to add the `-fobjc-arc`
      #         flag for compatibility.
      #
      attr_accessor :set_arc_compatibility_flag

      #-----------------------------------------------------------------------#

      # Generates the xcconfig for the library.
      #
      # @return [Xcodeproj::Config]
      #
      # @note   The value `PODS_HEADERS_SEARCH_PATHS` is used to store the headers
      #         so xcconfig can reference the variable.
      #
      # @todo   Add Xcodeproj::Config#[]
      #
      def generate
        ld_flags = '-ObjC'
        if  set_arc_compatibility_flag && pods.any? { |pod| pod.requires_arc? }
          ld_flags << ' -fobjc-arc'
        end

        @xcconfig = Xcodeproj::Config.new({
          'ALWAYS_SEARCH_USER_PATHS'         => 'YES',
          'OTHER_LDFLAGS'                    => ld_flags,
          'HEADER_SEARCH_PATHS'              => '${PODS_HEADERS_SEARCH_PATHS}',
          'PODS_ROOT'                        => relative_pods_root,
          'PODS_HEADERS_SEARCH_PATHS'        => '${PODS_PUBLIC_HEADERS_SEARCH_PATHS}',
          'PODS_BUILD_HEADERS_SEARCH_PATHS'  => quote(sandbox.build_headers.search_paths),
          'PODS_PUBLIC_HEADERS_SEARCH_PATHS' => quote(sandbox.public_headers.search_paths),
        })
        pods.each { |pod| @xcconfig.merge!(pod.xcconfig) }
        @xcconfig
      end

      # @return [Xcodeproj::Config] The generated xcconfig.
      #
      attr_reader :xcconfig

      # @return [Hash] The settings of the xcconfig that the Pods project
      #         needs to override.
      #
      def self.pods_project_settings
        { 'PODS_ROOT' => '${SRCROOT}',
          'PODS_HEADERS_SEARCH_PATHS' => '${PODS_BUILD_HEADERS_SEARCH_PATHS}' }
      end

      # Generates and saves the xcconfig to the given path.
      #
      # @param  [Pathname] path
      #         the path where the prefix header should be stored.
      #
      # @return [void]
      #
      def save_as(path)
        path.open('w') { |file| file.write(generate) }
      end

      #-----------------------------------------------------------------------#

      # @!group Private helpers.

      private

      # @return [String] the default linker flags. `-ObjC` is always included
      #         while `-fobjc-arc` is included only if requested in the
      #         Podfile.
      #
      def default_ld_flags
        flags = %w[ -ObjC ]
        requires_arc = pods.any? { |pod| pod.requires_arc? }
        if  requires_arc && set_arc_compatibility_flag
          flags << '-fobjc-arc'
        end
        flags.join(" ")
      end

      # Converts an array of strings to a single string where the each string
      # is surrounded by double quotes and separated by a space. Used to
      # represent strings in a xcconfig file.
      #
      # @param  [Array<String>] strings
      #         a list of strings.
      #
      # @return [String] the resulting string.
      #
      def quote(strings)
        strings.map { |s| %W|"#{s}"| }.join(" ")
      end
    end
  end
end

