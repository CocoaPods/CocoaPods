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
  #     +-- User
  #     | +-- [Target Name]-configuration.h
  #     | +-- Specs
  #     | +-- Scripts
  #     |
  #     +-- Generated
  #       +-- Headers
  #       |   +-- Private
  #       |   |   +-- [Pod Name]
  #       |   +-- Public
  #       |       +-- [Pod Name]
  #       |
  #       +-- Sources
  #       |   +-- [Pod Name]
  #       |
  #       +-- Specs
  #       |   +-- External Sources
  #       |   +-- Normal Sources
  #       |
  #       +-- Target Support Files
  #       |   +-- [Target Name]
  #       |       +-- Pods-acknowledgements.markdown
  #       |       +-- Pods-acknowledgements.plist
  #       |       +-- Pods-dummy.m
  #       |       +-- Pods-prefix.pch
  #       |       +-- Pods.xcconfig
  #       |
  #       +-- Manifest.lock
  #       |
  #       +-- Pods.xcodeproj
  #
  # See #833
  #
  class Sandbox

    autoload :FileAccessor, 'cocoapods/sandbox/file_accessor'
    autoload :HeadersStore, 'cocoapods/sandbox/headers_store'
    autoload :PathList,     'cocoapods/sandbox/path_list'

    # @return [Pathname] the root of the sandbox.
    #
    attr_reader :root

    # @return [HeadersStore] the header directory for the user targets.
    #
    attr_reader :public_headers

    # @param [String, Pathname] root @see root
    #
    def initialize(root)
      @root = Pathname.new(root)
      @public_headers = HeadersStore.new(self, "Headers")
      @predownloaded_pods = []
      @head_pods = []
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

    # Removes the files of the Pod with the given name from the sandbox.
    #
    # @return [void]
    #
    def clean_pod(name)
      root_name = Specification.root_name(name)
      unless local?(root_name)
        path = pod_dir(name)
        path.rmtree if path.exist?
      end
      podspe_path = specification_path(name)
      podspe_path.rmtree if podspe_path
    end

    # @return [String] a string representation suitable for debugging.
    #
    def inspect
      "#<#{self.class}> with root #{root}"
    end

    #-------------------------------------------------------------------------#

    public

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

    # @return [Pathname] the directory where to store the documentation.
    #
    def documentation_dir
      root + 'Documentation'
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Specification store

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

    # @return [Pathname] the path for the directory where to store the
    #         specifications.
    #
    # @todo   Migrate old installations and store the for all the pods.
    #         Two folders should be created `External Sources` and `Podspecs`.
    #
    def specifications_dir(external_source = false)
      # root + "Specifications"
      root + "Local Podspecs"
    end

    # Returns the path of the specification for the Pod with the
    # given name, if one is stored.
    #
    # @param  [String] name
    #         the name of the Pod for which the podspec file is requested.
    #
    # @return [Pathname] the path or nil.
    # @return [Nil] if the podspec is not stored.
    #
    def specification_path(name)
      path = specifications_dir + "#{name}.podspec"
      path.exist? ? path : nil
    end

    # Stores a specification in the `Local Podspecs` folder.
    #
    # @param  [Sandbox] sandbox
    #         the sandbox where the podspec should be stored.
    #
    # @param  [String, Pathname] podspec
    #         The contents of the specification (String) or the path to a
    #         podspec file (Pathname).
    #
    # @todo   Store all the specifications (including those not originating
    #         from external sources) so users can check them.
    #
    def store_podspec(name, podspec, external_source = false)
      output_path = specifications_dir(external_source) + "#{name}.podspec"
      output_path.dirname.mkpath
      if podspec.is_a?(String)
        output_path.open('w') { |f| f.puts(podspec) }
      else
        unless podspec.exist?
          raise Informative, "No podspec found for `#{name}` in #{podspec}"
        end
        FileUtils.copy(podspec, output_path)
      end
      spec = Specification.from_file(output_path)
      unless spec.name == name
        raise Informative, "The name of the given podspec `#{spec.name}` doesn't match the expected one `#{name}`"
      end
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Pods information

    # Marks a Pod as pre-downloaded
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [void]
    #
    def store_pre_downloaded_pod(name)
      root_name = Specification.root_name(name)
      predownloaded_pods << root_name
    end

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

    # Marks a Pod as head.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [void]
    #
    def store_head_pod(name)
      root_name = Specification.root_name(name)
      head_pods << root_name
    end

    # @return [Array<String>] The names of the pods that have been
    #         marked as head.
    #
    attr_reader :head_pods

    # Checks if a Pod should attempt to use the head source of the git repo.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [Bool] Whether the Pod has been marked as head.
    #
    def head_pod?(name)
      root_name = Specification.root_name(name)
      head_pods.include?(root_name)
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
    # @todo   Rename (e.g. `pods_with_local_path`)
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

