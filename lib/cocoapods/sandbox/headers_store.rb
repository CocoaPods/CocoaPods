module Pod
  class Sandbox

    # Provides support for managing a header directory. It also keeps track of
    # the header search paths.
    #
    class HeadersStore

      # @return [Pathname] the absolute path of this header directory.
      #
      def root
        @sandbox.root + @relative_path
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
        @search_paths  = [relative_path]
      end

      # @return [Array<String>] All the search paths of the header directory in
      #         xcconfig format. The paths are specified relative to the pods
      #         root with the `${PODS_ROOT}` variable.
      #
      def search_paths
        @search_paths.uniq.map { |path| "${PODS_ROOT}/#{path}" }
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

      # Adds a header to the directory.
      #
      # @param  [Pathname] namespace_path
      #         the path where the header file should be stored relative to the
      #         headers directory.
      #
      # @param  [Pathname] relative_header_path
      #         the path of the header file relative to the sandbox.
      #
      # @note   This method adds the files to the search paths.
      #
      # @return [Pathname]
      #
      def add_files(namespace, relative_header_paths)
        add_search_path(namespace)
        namespaced_path = root + namespace
        namespaced_path.mkpath unless File.exist?(namespaced_path)

        relative_header_paths.map do |relative_header_path|
          source = (@sandbox.root + relative_header_path).relative_path_from(namespaced_path)
          Dir.chdir(namespaced_path) do
            FileUtils.ln_sf(source, relative_header_path.basename)
          end
          namespaced_path + relative_header_path.basename
        end
      end

      # Adds an header search path to the sandbox.
      #
      # @param  [Pathname] path
      #         the path tho add.
      #
      # @return [void]
      #
      def add_search_path(path)
        @search_paths << Pathname.new(@relative_path) + path
      end

      #-----------------------------------------------------------------------#

    end
  end
end
