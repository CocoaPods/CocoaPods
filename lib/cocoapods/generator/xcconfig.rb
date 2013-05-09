module Pod
  module Generator

    # Generates Xcode configuration files. A configuration file is generated
    # for each Pod and for each Pod target definition. The aggregates the
    # configurations of the Pods and define target specific settings.
    #
    class XCConfig

      # @return [Target] the library or target represented by this xcconfig.
      #
      attr_reader :library

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

      # @param  [Target] library @see library
      # @param  [Array<Specification::Consumer>] spec_consumers @see spec_consumers
      # @param  [String] relative_pods_root @see relative_pods_root
      #
      def initialize(library, spec_consumers, relative_pods_root)
        @library = library
        @sandbox = library.sandbox
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
      # @note   The xcconfig file for a spec derived target includes namespaced
      #         configuration values, the private build headers and headermap
      #         disabled. The xcconfig file for the Pods integration target
      #         then includes the spec xcconfig and incorporates the namespaced
      #         configuration values like preprocessor overrides or frameworks
      #         to link with.
      #
      # @return [Xcodeproj::Config]
      #
      def generate
        ld_flags = '-ObjC'
        if  set_arc_compatibility_flag && spec_consumers.any? { |consumer| consumer.requires_arc }
          ld_flags << ' -fobjc-arc'
        end

        if library.spec
          config = {
            'ALWAYS_SEARCH_USER_PATHS'     => 'YES',
            'OTHER_LDFLAGS'                => ld_flags,
            'PODS_ROOT'                    => '${SRCROOT}',
            'HEADER_SEARCH_PATHS'          => quote(library.build_headers.search_paths) + ' ' + quote(sandbox.public_headers.search_paths),
            'GCC_PREPROCESSOR_DEFINITIONS' => 'COCOAPODS=1',
            # 'USE_HEADERMAP'                => 'NO'
          }

          consumer_xcconfig(library.consumer).to_hash.each do |k, v|
            prefixed_key = library.xcconfig_prefix + k
            config[k] = "#{config[k]} ${#{prefixed_key}}"
            config[prefixed_key] = v
          end
        else
          config = {
            'ALWAYS_SEARCH_USER_PATHS'         => 'YES',
            'OTHER_LDFLAGS'                    => ld_flags,
            'HEADER_SEARCH_PATHS'              => '${PODS_HEADERS_SEARCH_PATHS}',
            'PODS_ROOT'                        => relative_pods_root,
            'PODS_HEADERS_SEARCH_PATHS'        => '${PODS_PUBLIC_HEADERS_SEARCH_PATHS}',
            'PODS_BUILD_HEADERS_SEARCH_PATHS'  => '',
            'PODS_PUBLIC_HEADERS_SEARCH_PATHS' => quote(sandbox.public_headers.search_paths),
            'GCC_PREPROCESSOR_DEFINITIONS'     => '$(inherited) COCOAPODS=1',
          }

          library.libraries.each do |lib|
            consumer_xcconfig(lib.consumer).to_hash.each do |k, v|
              prefixed_key = lib.xcconfig_prefix + k
              config[k] = "#{config[k]} ${#{prefixed_key}}"
            end
          end
        end

        @xcconfig = Xcodeproj::Config.new(config)
        @xcconfig.includes = library.libraries.map(&:name) unless library.spec
        @xcconfig
      end

      # @return [Xcodeproj::Config] The generated xcconfig.
      #
      attr_reader :xcconfig

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

      # Returns the Xcconfig generated from the build settings of the give
      # specification consumer.
      #
      # @param  [Specification::Consumer] consumer
      #         The consumer of the specification.
      #
      # @param  [Xcodeproj::Config] xcconfig
      #         The xcconfig to edit.
      #
      # @return [Xcodeproj::Config]
      #
      def consumer_xcconfig(consumer)
        xcconfig = Xcodeproj::Config.new()
        xcconfig.merge!(consumer.xcconfig)
        xcconfig.libraries.merge(consumer.libraries)
        xcconfig.frameworks.merge(consumer.frameworks)
        xcconfig.weak_frameworks.merge(consumer.weak_frameworks)
        add_developers_frameworks_if_needed(consumer, xcconfig)
        xcconfig
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

