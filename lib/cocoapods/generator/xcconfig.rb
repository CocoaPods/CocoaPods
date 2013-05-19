module Pod
  module Generator

    # Generates Xcode configuration files. A configuration file is generated
    # for each Pod and for each Pod target definition. The aggregates the
    # configurations of the Pods and define target specific settings.
    #
    class AbstractXCConfig

      # @return [Target] the library or target represented by this xcconfig.
      #
      attr_reader :library
      attr_reader :sandbox

      # @param  [Target] library @see library
      #
      def initialize(library)
        @library = library
        @sandbox = library.sandbox
      end

      # Generates and saves the xcconfig to the given path.
      #
      # @param  [Pathname] path
      #         the path where the prefix header should be stored.
      #
      # @return [void]
      #
      def save_as(path)
        generate.save_as(path)
      end

      #-----------------------------------------------------------------------#

      # @!group Private helpers.

      private

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
        xcconfig = Xcodeproj::Config.new(consumer.xcconfig)
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

    #-------------------------------------------------------------------------#

    class PodXCConfig < AbstractXCConfig

      # Generates the xcconfig for the Pod integration target.
      #
      # @note   The xcconfig file for a Pods integration target includes the
      #         namespaced xcconfig files for each spec target dependency.
      #         Each namespaced configuration value is merged into the Pod
      #         xcconfig file.
      #
      # @return [Xcodeproj::Config]
      #
      def generate
        ld_flags = '-ObjC'
        if library.target_definition.podfile.set_arc_compatibility_flag?
          ld_flags << ' -fobjc-arc'
        end

        config = {
          'ALWAYS_SEARCH_USER_PATHS'         => 'YES',
          'OTHER_LDFLAGS'                    => ld_flags,
          'HEADER_SEARCH_PATHS'              => quote(sandbox.public_headers.search_paths),
          'PODS_ROOT'                        => library.relative_pods_root,
          'GCC_PREPROCESSOR_DEFINITIONS'     => '$(inherited) COCOAPODS=1',
        }

        library.libraries.each do |lib|
          consumer_xcconfig(lib.consumer).to_hash.each do |k, v|
            prefixed_key = lib.xcconfig_prefix + k
            config[k] = "#{config[k]} ${#{prefixed_key}}"
          end
        end

        xcconfig = Xcodeproj::Config.new(config)
        xcconfig.includes = library.libraries.map(&:name)
        xcconfig
      end

    end

    #-------------------------------------------------------------------------#

    class PublicSpecXCConfig < AbstractXCConfig

      # Generates and saves the xcconfig to the given path.
      #
      # @param  [Pathname] path
      #         the path where the prefix header should be stored.
      #
      # @note   The public xcconfig file for a spec target is completely
      #         namespaced to prevent configuration value collision with other
      #         spec configurations.
      #
      # @return [void]
      #
      def save_as(path)
        generate.save_as(path, library.xcconfig_prefix)
      end

      # Generates the xcconfig for the library.
      #
      # @note   The xcconfig file for a public spec target includes the
      #         standard podspec defined values including libraries,
      #         frameworks, weak frameworks and xcconfig overrides.
      #
      # @return [Xcodeproj::Config]
      #
      def generate
        consumer_xcconfig(library.consumer)
      end

    end

    #-------------------------------------------------------------------------#

    class PrivateSpecXCConfig < AbstractXCConfig

      # Generates the xcconfig for the library.
      #
      # @note   The private xcconfig file for a spec target includes the public
      #         namespaced xcconfig file and merges the configuration values
      #         with the default private configuration values.
      #
      # @return [Xcodeproj::Config]
      #
      def generate
        ld_flags = '-ObjC'
        if library.consumer.requires_arc?
          ld_flags << ' -fobjc-arc'
        end

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
        end

        xcconfig = Xcodeproj::Config.new(config)
        xcconfig.includes = [library.name]
        xcconfig
      end

    end

    #-------------------------------------------------------------------------#

  end
end

