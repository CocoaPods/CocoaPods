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

      # @return [Sandbox::PathList] the directory where the source of the Pod
      #         is located.
      #
      attr_reader :path_list

      # @return [Specification::Consumer] the consumer of the specification for
      #         which the file patterns should be resolved.
      #
      attr_reader :spec_consumer

      # @param [Sandbox::PathList] path_list @see path_list
      # @param [Specification::Consumer] spec_consumer @see spec_consumer
      #
      def initialize(path_list, spec_consumer)
        @path_list = path_list
        @spec_consumer = spec_consumer

        unless @spec_consumer
          raise Informative, "Attempt to initialize File Accessor without a specification consumer."
        end
      end

      # @return [Pathname] the directory which contains the files of the Pod.
      #
      def root
        path_list.root
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
        "<#{self.class} spec=#{spec.name} platform=#{platform_name} root=#{path_list.root}>"
      end

      #-----------------------------------------------------------------------#

      public

      # @!group Paths

      # @return [Array<Pathname>] the source files of the specification.
      #
      def source_files
        paths_for_attribute(:source_files)
      end

      # @return [Array<Pathname>] the headers of the specification.
      #
      def headers
        extensions = HEADER_EXTENSIONS
        source_files.select { |f| extensions.include?(f.extname) }
      end

      # @return [Array<Pathname>] the public headers of the specification.
      #
      def public_headers
        public_headers = paths_for_attribute(:public_header_files)
        private_headers = paths_for_attribute(:private_header_files)
        if public_headers.nil? || public_headers.empty?
          header_files = headers
        else
          header_files = public_headers
        end
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
        path_list.glob(%w[ readme{*,.*} ]).first
      end

      # @return [Pathname] The path of the license file as indicated in the
      #         specification or auto-detected.
      #
      def license
        if spec_consumer.spec.root.license[:file]
          path_list.root + spec_consumer.spec.root.license[:file]
        else
          path_list.glob(%w[ licen{c,s}e{*,.*} ]).first
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
          :dir_pattern => glob_for_attribute(attribute),
          :include_dirs => include_dirs,
        }
        expanded_paths(file_patterns, options)
      end

      # Returns the pattern to use to glob a directory for an attribute.
      #
      # @param  [Symbol] attribute
      #         the name of the attribute
      #
      # @return [String] the glob pattern.
      #
      # @todo   Move to the cocoapods-core so it appears in the docs?
      #
      def glob_for_attribute(attrbute)
        globs = {
          :source_files => '*.{h,hpp,hh,m,mm,c,cpp}'.freeze,
          :public_header_files => "*.{#{ HEADER_EXTENSIONS * ',' }}".freeze,
        }
        globs[attrbute]
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
      # @todo   Implement case insensitive search
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


