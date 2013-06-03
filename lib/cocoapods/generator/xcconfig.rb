module Pod
  module Generator

    # Generates an xcconfig file for each target of the Pods project. The
    # configuration file should be used by the user target as well.
    #
    class XCConfig

      # @return [Sandbox] the sandbox where the Pods project is installed.
      #
      attr_reader :sandbox

      # @return [Array<Specification::Consumer>] the consumers for the
      #         specifications of the library which needs the xcconfig.
      #
      attr_reader :spec_consumers

      # @return [String] the relative path of the Pods root respect the user
      #         project that should be integrated by this library.
      #
      attr_reader :relative_pods_root

      # @param  [Sandbox] sandbox @see sandbox
      # @param  [Array<LocalPod>] pods @see pods
      # @param  [String] relative_pods_root @see relative_pods_root
      #
      def initialize(sandbox, spec_consumers, relative_pods_root)
        @sandbox = sandbox
        @spec_consumers = spec_consumers
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
      def generate
        ld_flags = '-ObjC'
        if  set_arc_compatibility_flag && spec_consumers.any? { |consumer| consumer.requires_arc }
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
          'GCC_PREPROCESSOR_DEFINITIONS'     => '$(inherited) COCOAPODS=1'
        }, 'PODS_LDFLAGS')

        spec_consumers.each do |consumer|
          add_spec_build_settings_to_xcconfig(consumer, @xcconfig)
        end
        
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
        strings.sort.map { |s| %W|"#{s}"| }.join(" ")
      end

      # Configures the given Xcconfig according to the build settings of the
      # given Specification.
      #
      # @param  [Specification::Consumer] consumer
      #         The consumer of the specification.
      #
      # @param  [Xcodeproj::Config] xcconfig
      #         The xcconfig to edit.
      #
      # @return [void]
      #
      def add_spec_build_settings_to_xcconfig(consumer, xcconfig)
        xcconfig.merge!(consumer.xcconfig)
        xcconfig.libraries.merge(consumer.libraries)
        xcconfig.frameworks.merge(consumer.frameworks)
        xcconfig.weak_frameworks.merge(consumer.weak_frameworks)
        add_developers_frameworks_if_needed(consumer, xcconfig)
      end

      # @return [Array<String>] The search paths for the developer frameworks.
      #
      # @todo   Inheritance should be properly handled in Xcconfigs.
      #
      DEVELOPER_FRAMEWORKS_SEARCH_PATHS = [
        '$(inherited)',
        '"$(SDKROOT)/Developer/Library/Frameworks"',
        '"$(DEVELOPER_LIBRARY_DIR)/Frameworks"'
      ]

      # Adds the search paths of the developer frameworks to the specification
      # if needed. This is done because the `SenTestingKit` requires them and 
      # adding them to each specification which requires it is repetitive and
      # error prone.
      #
      # @param  [Specification::Consumer] consumer
      #         The consumer of the specification.
      #
      # @param  [Xcodeproj::Config] xcconfig
      #         The xcconfig to edit.
      #
      # @return [void]
      #
      def add_developers_frameworks_if_needed(consumer, xcconfig)
        if xcconfig.frameworks.include?('SenTestingKit')
          search_paths = xcconfig.attributes['FRAMEWORK_SEARCH_PATHS'] ||= ''
          DEVELOPER_FRAMEWORKS_SEARCH_PATHS.each do |search_path|
            unless search_paths.include?(search_path)
              search_paths << ' ' unless search_paths.empty?
              search_paths << search_path
            end
          end
        end
      end

      #-----------------------------------------------------------------------#

    end
  end
end

