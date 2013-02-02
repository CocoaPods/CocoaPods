require 'fileutils'

module Pod

  # The sandbox provides support for the directory that CocoaPods uses for an
  # installation. In this directory the Pods projects, the support files and
  # the sources of the Pods are stored.
  #
  # CocoaPods assumes to have control of the sandbox.
  #
  # Once completed the sandbox will have the following file structure:
  #
  #     Pods
  #     |
  #     +-- Headers
  #     |   +-- Build
  #     |   |   +-- [Pod Name]
  #     |   +-- Public
  #     |       +-- [Pod Name]
  #     |
  #     +-- Sources
  #     |   +-- [Pod Name]
  #     |
  #     +-- Specifications
  #     |
  #     +-- Target Support Files
  #     |   +-- [Target Name]
  #     |       +-- Acknowledgements.markdown
  #     |       +-- Acknowledgements.plist
  #     |       +-- Pods.xcconfig
  #     |       +-- Pods-prefix.pch
  #     |       +-- PodsDummy_Pods.m
  #     |
  #     +-- Manifest.lock
  #     |
  #     +-- Pods.xcodeproj
  #
  class Sandbox

    autoload :PathList,     'cocoapods/sandbox/path_list'
    autoload :FileAccessor, 'cocoapods/sandbox/file_accessor'

    # @return [Pathname] the root of the sandbox.
    #
    attr_reader :root

    # @return [HeadersStore] the header directory for the Pods libraries.
    #
    attr_reader :build_headers

    # @return [HeadersStore] the header directory for the user targets.
    #
    attr_reader :public_headers

    # @param [String, Pathname] root @see root
    #
    def initialize(root)
      @root = Pathname.new(root)
      @build_headers  = HeadersStore.new(self, "BuildHeaders")
      @public_headers = HeadersStore.new(self, "Headers")
      @predownloaded_pods = []
      FileUtils.mkdir_p(@root)
    end

    # @return [Lockfile] the manifest which contains the information about the
    #         installed pods.
    #
    def manifest
      Lockfile.from_file(manifest_path) if manifest_path.exist?
    end

    # @return [Project] the Pods project.
    #
    attr_accessor :project

    # Removes the sandbox.
    #
    # @return [void]
    #
    def implode
      root.rmtree
    end

    # @return [Pathname] Returns the relative path from the sandbox.
    #
    # @note If the two absolute paths don't share the same root directory an
    #       extra `../` is added to the result of {Pathname#relative_path_from}
    #
    #
    # @example
    #
    #   path = Pathname.new('/Users/dir')
    #   @sandbox.root #=> Pathname('/tmp/CocoaPods/Lint/Pods')
    #
    #   @sandbox.relativize(path) #=> '../../../../Users/dir'
    #   @sandbox.relativize(path) #=> '../../../../../Users/dir'
    #
    def relativize(path)
      result = path.relative_path_from(root)
      unless root.to_s.split('/')[1] == path.to_s.split('/')[1]
        result = Pathname.new('../') + result
      end
      result
    end

    # Converts a list of paths to their relative variant.
    #
    # @return [Array<Pathname>] the relative paths.
    #
    def relativize_paths(paths)
      paths.map { |path| relativize(path) }
    end

    # @return [String] a string representation suitable for debugging.
    #
    def inspect
      "#<#{self.class}> with root #{root}"
    end

    #--------------------------------------#

    # @!group Paths

    # @return [Pathname] the path of the manifest.
    #
    def manifest_path
      root + "Manifest.lock"
    end

    # @return [Pathname] the path of the Pods project.
    #
    def project_path
      root + "Pods.xcodeproj"
    end

    # Returns the path for the Pod with the given name.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [Pathname] the path of the Pod.
    #
    def pod_dir(name)
      # root + "Sources/#{name}"
      root + name
    end

    # Returns the path for the directory where to store the support files of
    # a target.
    #
    # @param  [String] name
    #         The name of the target.
    #
    # @return [Pathname] the path of the support files.
    #
    def library_support_files_dir(name)
      # root + "Target Support Files/#{name}"
      root
    end

    # @return [Pathname] the path for the directory where to store the
    #         specifications.
    #
    def specifications_dir
      # root + "Specifications"
      root + "Local Podspecs"
    end

    # Returns the path of the specification for the Pod with the
    # given name.
    #
    # @param  [String] name
    #         the name of the Pod for which the podspec file is requested.
    #
    # @return [Pathname] the path or nil.
    #
    def specification_path(name)
      path = specifications_dir + "#{name}.podspec"
      path.exist? ? path : nil
    end

    #--------------------------------------#

    # @!group Pods Installation

    # Returns the specification for the Pod with the given name.
    #
    # @param  [String] name
    #         the name of the Pod for which the specification is requested.
    #
    # @return [Specification] the specification if the file is found.
    #
    def specification(name)
      if file = specification_path(name)
        Specification.from_file(file)
      end
    end

    # @return [Array<String>] the names of the pods that have been
    #         pre-downloaded from an external source.
    #
    attr_reader :predownloaded_pods

    #-------------------------------------------------------------------------#

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

      #--------------------------------------#

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
      # @note   This method adds the files are added to the search paths.
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
    end

    #-------------------------------------------------------------------------#

  end
end

