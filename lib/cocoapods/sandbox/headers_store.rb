module Pod
  class Sandbox
    # Provides support for managing a header directory. It also keeps track of
    # the header search paths.
    #
    class HeadersStore
      # @return [Pathname] the absolute path of this header directory.
      #
      def root
        sandbox.headers_root + @relative_path
      end

      # @return [Sandbox] the sandbox where this header directory is stored.
      #
      attr_reader :sandbox

      # @param  [Sandbox] @see sandbox
      #
      # @param  [String] relative_path
      #         the relative path to the sandbox root and hence to the Pods
      #         project.
      #
      def initialize(sandbox, relative_path)
        @sandbox       = sandbox
        @relative_path = relative_path
        @search_paths  = []
        @search_paths_cache = {}
        @search_paths_key = Struct.new(:platform_name, :target_name)
      end

      # @param  [Platform] platform
      #         the platform for which the header search paths should be
      #         returned
      #
      # @param  [Target] target
      #         the target for which the header search paths should be
      #         returned, may be `nil`.
      #
      # @return [Array<String>] All the search paths of the header directory in
      #         xcconfig format. The paths are specified relative to the pods
      #         root with the `${PODS_ROOT}` variable.
      #
      def search_paths(platform, target = nil)
        target_name = nil
        target_name = target.name unless target.nil?
        key = @search_paths_key.new(platform.name, target_name)
        if @search_paths_cache.key?(key)
          return @search_paths_cache[key]
        end
        platform_search_paths = @search_paths.select do |entry|
          matches_platform = entry[:platform] == platform.name
          next matches_platform if target.nil?
          matches_platform && entry[:path].basename.to_s == target.name
        end
        headers_dir = root.relative_path_from(sandbox.root).dirname
        @search_paths_cache[key] = platform_search_paths.uniq.map { |entry| "${PODS_ROOT}/#{headers_dir}/#{entry[:path]}" }
      end

      # Removes the directory as it is regenerated from scratch during each
      # installation.
      #
      # @return [void]
      #
      def implode!
        root.rmtree if root.exist?
      end

      #-----------------------------------------------------------------------#

      public

      # @!group Adding headers

      # Adds headers to the directory.
      #
      # @param  [Pathname] namespace
      #         the path where the header file should be stored relative to the
      #         headers directory.
      #
      # @param  [Array<Pathname>] relative_header_paths
      #         the path of the header file relative to the Pods project
      #         (`PODS_ROOT` variable of the xcconfigs).
      #
      # @param  [Boolean] public_header
      #          whether this header is a public header or not
      #
      # @note   This method does _not_ add the files to the search paths.
      #
      # @return [Array<Pathname>]
      #
      def add_files(namespace, relative_header_paths, public_header = false)
        relative_header_paths.map do |relative_header_path|
          add_file(namespace, relative_header_path, public_header)
        end
      end

      # Adds a header to the directory.
      #
      # @param  [Pathname] namespace
      #         the path where the header file should be stored relative to the
      #         headers directory.
      #
      # @param  [Pathname] relative_header_path
      #         the path of the header file relative to the Pods project
      #         (`PODS_ROOT` variable of the xcconfigs).
      #
      # @param  [Boolean] public_header
      #          whether this header is a public header or not
      #
      # @note   This method does _not_ add the file to the search paths.
      #
      # @return [Pathname]
      #
      def add_file(namespace, relative_header_path, public_header = false)
        namespaced_path = root + namespace
        # If this is a public header add another subfolder for '<>' imports to work.
        # e.g `./Pods/Headers/Public/SampleLibrary/SampleLibrary/SampleLibrary.h`
        namespaced_path += namespace if public_header
        namespaced_path.mkpath unless File.exist?(namespaced_path)

        absolute_source = (sandbox.root + relative_header_path)
        source = absolute_source.relative_path_from(namespaced_path)
        FileUtils.ln_sf(source, namespaced_path)
        namespaced_path + relative_header_path.basename
      end

      # Adds an header search path to the sandbox.
      #
      # @param  [Pathname] path
      #         the path tho add.
      #
      # @param  [String] platform
      #         the platform the search path applies to
      #
      # @return [void]
      #
      def add_search_path(path, platform)
        @search_paths << { :platform => platform.name, :path => (Pathname.new(@relative_path) + path) }
      end

      #-----------------------------------------------------------------------#
    end
  end
end
