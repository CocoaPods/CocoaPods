module Pod
  class Sandbox
    # Resolves the file patterns of a specification against its root directory,
    # taking into account any exclude pattern and the default extensions to use
    # for directories.
    #
    # @note The FileAccessor always returns absolute paths.
    #
    class FileAccessor
      HEADER_EXTENSIONS = Xcodeproj::Constants::HEADER_FILES_EXTENSIONS

      GLOB_PATTERNS = {
        :readme              => 'readme{*,.*}'.freeze,
        :license             => 'licen{c,s}e{*,.*}'.freeze,
        :source_files        => '*.{h,hpp,hh,m,mm,c,cpp}'.freeze,
        :public_header_files => "*{#{HEADER_EXTENSIONS.join(',')}}".freeze,
      }.freeze

      # @return [Sandbox::PathList] the directory where the source of the Pod
      #         is located.
      #
      attr_reader :path_list

      # @return [Specification::Consumer] the consumer of the specification for
      #         which the file patterns should be resolved.
      #
      attr_reader :spec_consumer

      # @param [Sandbox::PathList, Pathname] path_list @see path_list
      # @param [Specification::Consumer] spec_consumer @see spec_consumer
      #
      def initialize(path_list, spec_consumer)
        if path_list.is_a?(PathList)
          @path_list = path_list
        else
          @path_list = PathList.new(path_list)
        end
        @spec_consumer = spec_consumer

        unless @spec_consumer
          raise Informative, 'Attempt to initialize File Accessor without a specification consumer.'
        end
      end

      # @return [Pathname] the directory which contains the files of the Pod.
      #
      def root
        path_list.root if path_list
      end

      # @return [Specification] the specification.
      #
      def spec
        spec_consumer.spec
      end

      # @return [Specification] the platform used to consume the specification.
      #
      def platform_name
        spec_consumer.platform_name
      end

      # @return [String] A string suitable for debugging.
      #
      def inspect
        "<#{self.class} spec=#{spec.name} platform=#{platform_name} root=#{root}>"
      end

      #-----------------------------------------------------------------------#

      public

      # @!group Paths

      # @return [Array<Pathname>] the source files of the specification.
      #
      def source_files
        paths_for_attribute(:source_files)
      end

      # @return [Array<Pathname>] the source files of the specification that
      #                           use ARC.
      #
      def arc_source_files
        case spec_consumer.requires_arc
        when TrueClass
          source_files
        when FalseClass
          []
        else
          paths_for_attribute(:requires_arc) & source_files
        end
      end

      # @return [Array<Pathname>] the source files of the specification that
      #                           do not use ARC.
      #
      def non_arc_source_files
        source_files - arc_source_files
      end

      # @return [Array<Pathname>] the headers of the specification.
      #
      def headers
        extensions = HEADER_EXTENSIONS
        source_files.select { |f| extensions.include?(f.extname) }
      end

      # @param [Boolean] include_frameworks
      #        Whether or not to include the headers of the vendored frameworks.
      #        Defaults to not include them.
      #
      # @return [Array<Pathname>] the public headers of the specification.
      #
      def public_headers(include_frameworks = false)
        public_headers = paths_for_attribute(:public_header_files)
        private_headers = paths_for_attribute(:private_header_files)
        if public_headers.nil? || public_headers.empty?
          header_files = headers
        else
          header_files = public_headers
        end
        header_files += vendored_frameworks_headers if include_frameworks
        header_files - private_headers
      end

      # @return [Hash{ Symbol => Array<Pathname> }] the resources of the
      #         specification grouped by destination.
      #
      def resources
        paths_for_attribute(:resources, true)
      end

      # @return [Array<Pathname>] the files of the specification to preserve.
      #
      def preserve_paths
        paths_for_attribute(:preserve_paths, true)
      end

      # @return [Array<Pathname>] The paths of the framework bundles that come
      #         shipped with the Pod.
      #
      def vendored_frameworks
        paths_for_attribute(:vendored_frameworks, true)
      end

      # @return [Array<Pathname>] The paths of the framework headers that come
      #         shipped with the Pod.
      #
      def vendored_frameworks_headers
        vendored_frameworks.map do |framework|
          headers_dir = (framework + 'Headers').realpath
          Pathname.glob(headers_dir + GLOB_PATTERNS[:public_header_files])
        end.flatten.uniq
      end

      # @return [Array<Pathname>] The paths of the library bundles that come
      #         shipped with the Pod.
      #
      def vendored_libraries
        paths_for_attribute(:vendored_libraries)
      end

      # @return [Hash{String => Array<Pathname>}] A hash that describes the
      #         resource bundles of the Pod. The keys reppresent the name of
      #         the bundle while the values the path of the resources.
      #
      def resource_bundles
        result = {}
        spec_consumer.resource_bundles.each do |name, file_patterns|
          paths = expanded_paths(file_patterns, :include_dirs => true)
          result[name] = paths
        end
        result
      end

      # @return [Array<Pathname>] The paths of the files which should be
      #         included in resources bundles by the Pod.
      #
      def resource_bundle_files
        resource_bundles.values.flatten
      end

      # @return [Pathname] The of the prefix header file of the specification.
      #
      def prefix_header
        if spec_consumer.prefix_header_file
          path_list.root + spec_consumer.prefix_header_file
        end
      end

      # @return [Pathname] The path of the auto-detected README file.
      #
      def readme
        path_list.glob([GLOB_PATTERNS[:readme]]).first
      end

      # @return [Pathname] The path of the license file as indicated in the
      #         specification or auto-detected.
      #
      def license
        if spec_consumer.spec.root.license[:file]
          path_list.root + spec_consumer.spec.root.license[:file]
        else
          path_list.glob([GLOB_PATTERNS[:license]]).first
        end
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Private helpers

      # Returns the list of the paths founds in the file system for the
      # attribute with given name. It takes into account any dir pattern and
      # any file excluded in the specification.
      #
      # @param  [Symbol] attribute
      #         the name of the attribute.
      #
      # @return [Array<Pathname>] the paths.
      #
      def paths_for_attribute(attribute, include_dirs = false)
        file_patterns = spec_consumer.send(attribute)
        options = {
          :exclude_patterns => spec_consumer.exclude_files,
          :dir_pattern => GLOB_PATTERNS[attribute],
          :include_dirs => include_dirs,
        }
        expanded_paths(file_patterns, options)
      end

      # Matches the given patterns to the file present in the root of the path
      # list.
      #
      # @param [Array<String>] patterns
      #         The patterns to expand.
      #
      # @param  [String] dir_pattern
      #         The pattern to add to directories.
      #
      # @param  [Array<String>] exclude_patterns
      #         The exclude patterns to pass to the PathList.
      #
      # @raise  [Informative] If the pod does not exists.
      #
      # @return [Array<Pathname>] A list of the paths.
      #
      def expanded_paths(patterns, options = {})
        return [] if patterns.empty?
        result = []
        result << path_list.glob(patterns, options)
        result.flatten.compact.uniq
      end

      #-----------------------------------------------------------------------#
    end
  end
end
