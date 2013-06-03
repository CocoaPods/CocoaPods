module Pod
  module Generator

    # Generates Xcode configuration files. A configuration file is generated
    # for each Pod and for each Pod target definition. The aggregates the
    # configurations of the Pods and define target specific settings.
    #
    class XCConfig

      # @return [Target] the target represented by this xcconfig.
      #
      attr_reader :target
      attr_reader :sandbox

      # @param  [Target] target @see target
      #
      def initialize(target)
        @target = target
        @sandbox = target.sandbox
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
        '"$(SDKROOT)/Developer/target/Frameworks"',
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

