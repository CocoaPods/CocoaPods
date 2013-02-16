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
  #     |       +-- Pods-dummy_Pods.m
  #     |
  #     +-- Manifest.lock
  #     |
  #     +-- Pods.xcodeproj
  #
  class Sandbox

    autoload :FileAccessor, 'cocoapods/sandbox/file_accessor'
    autoload :HeadersStore, 'cocoapods/sandbox/headers_store'
    autoload :PathList,     'cocoapods/sandbox/path_list'

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
      @checkout_sources = {}
      @local_pods = {}
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

    #-------------------------------------------------------------------------#

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

    #-------------------------------------------------------------------------#

    # @!group Pods storage & source

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

    # Returns the path where the Pod with the given name is stored, taking into
    # account whether the Pod is locally sourced.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [Pathname] the path of the Pod.
    #
    def pod_dir(name)
      root_name = Specification.root_name(name)
      if local?(root_name)
        Pathname.new(local_pods[root_name])
      else
        # root + "Sources/#{name}"
        root + root_name
      end
    end

    #--------------------------------------#

    # @return [Array<String>] The names of the pods that have been
    #         pre-downloaded from an external source.
    #
    attr_reader :predownloaded_pods

    # Checks if a Pod has been pre-downloaded by the resolver in order to fetch
    # the podspec.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [Bool] Whether the Pod has been pre-downloaded.
    #
    def predownloaded?(name)
      root_name = Specification.root_name(name)
      predownloaded_pods.include?(root_name)
    end

    #--------------------------------------#

    # Stores the local path of a Pod.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @param  [Hash] source
    #         The hash which contains the options as returned by the
    #         downloader.
    #
    # @return [void]
    #
    def store_checkout_source(name, source)
      root_name = Specification.root_name(name)
      checkout_sources[root_name] = source
    end

    # @return [Hash{String=>Hash}] The options necessary to recreate the exact
    #         checkout of a given Pod grouped by its name.
    #
    attr_reader :checkout_sources

    #--------------------------------------#

    # Stores the local path of a Pod.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @param  [#to_s] path
    #         The local path where the Pod is stored.
    #
    # @return [void]
    #
    def store_local_path(name, path)
      root_name = Specification.root_name(name)
      local_pods[root_name] = path.to_s
    end

    # @return [Hash{String=>String}] The path of the Pods with a local source
    #         grouped by their name.
    #
    attr_reader :local_pods

    # Checks if a Pod is locally sourced?
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [Bool] Whether the Pod is locally sourced.
    #
    def local?(name)
      root_name = Specification.root_name(name)
      !local_pods[root_name].nil?
    end

    #-------------------------------------------------------------------------#

  end
end

