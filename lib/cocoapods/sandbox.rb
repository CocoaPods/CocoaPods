require 'fileutils'

module Pod

  # The sandbox provides support for the directory that CocoaPods uses for an
  # installation. In this directory the Pods projects, the support files and
  # the sources of the Pods are stored.
  #
  # CocoaPods assumes to have control of the sandbox.
  #
  class Sandbox

    # The path of the build headers directory relative to the root.
    #
    BUILD_HEADERS_DIR  = "BuildHeaders"

    # The path of the public headers directory relative to the root.
    #
    PUBLIC_HEADERS_DIR = "Headers"

    # @return [Pathname] the root of the sandbox.
    #
    attr_reader :root

    # @return [HeadersDirectory] the header directory for the Pods libraries.
    #
    attr_reader :build_headers

    # @return [HeadersDirectory] the header directory for the user targets.
    #
    attr_reader :public_headers

    # @param [String, Pathname] root @see root
    #
    # @todo the headers should be stored in a `Headers` folder.
    #
    def initialize(root)
      @root = Pathname.new(root)
      @build_headers  = HeadersDirectory.new(self, BUILD_HEADERS_DIR)
      @public_headers = HeadersDirectory.new(self, PUBLIC_HEADERS_DIR)
      @cached_local_pods = {}
      @cached_locally_sourced_pods = {}
      @predownloaded_pods = []
      FileUtils.mkdir_p(@root)
    end

    # @return [Pathname] the path of the Pod project.
    #
    def project_path
      root + "Pods.xcodeproj"
    end

    # @return [String] a string representation suitable for debugging.
    #
    def inspect
      "#<#{self.class}> with root #{root}"
    end

    #--------------------------------------#

    # @!group Life cycle

    public

    # Cleans the sandbox for a new installation.
    #
    # @return [void]
    #
    def prepare_for_install
      build_headers.prepare_for_install
      public_headers.prepare_for_install
    end

    # Removes the sandbox.
    #
    # @return [void]
    #
    def implode
      root.rmtree
    end

    #--------------------------------------#

    # @!group Local Pod support

    public

    # @todo   Refactor the pods from a local source should not be cached by the
    #         sandbox.
    #
    # @return [LocalPod]
    #
    def locally_sourced_pod_for_spec(spec, platform)
      key = [spec.root.name, platform.to_sym]
      local_pod = @cached_locally_sourced_pods[key] ||= LocalPod::LocalSourcedPod.new(spec.root, self, platform)
      local_pod.add_specification(spec)
      local_pod
    end

    def local_pod_for_spec(spec, platform)
      key = [spec.root.name, platform.to_sym]
      (@cached_local_pods[key] ||= LocalPod.new(spec.root, self, platform)).tap do |pod|
        pod.add_specification(spec)
      end
    end

    # @return [LocalPod]
    #
    def installed_pod_named(name, platform)
      if spec_path = podspec_for_name(name)
        key = [name, platform.to_sym]
        @cached_local_pods[key] ||= LocalPod.from_podspec(spec_path, self, platform)
      end
    end

    # Returns the path of the specification for the Pod with the
    # given name.
    #
    # @param  [String] name
    #         the name of the Pod for which the podspec file is requested.
    #
    # @return [Pathname] the path or nil.
    #
    def podspec_for_name(name)
      path = root + "Local Podspecs/#{name}.podspec"
      path.exist? ? path : nil
    end

    # Returns the specification for the Pod with the given name.
    #
    # @param  [String] name
    #         the name of the Pod for which the specification is requested.
    #
    # @return [Specification] the specification if the file is found.
    #
    def specification(name)
      if file = podspec_for_name(name)
        Specification.from_file(file)
      end
    end

    # @return [Array<String>] the names of the pods that have been
    #         pre-downloaded from an external source.
    #
    # @todo   The installer needs to be aware of it.
    #
    attr_reader :predownloaded_pods

    #--------------------------------------#

    # @!group Private methods

    private

    attr_accessor :cached_local_pods

    attr_accessor :cached_locally_sourced_pods
  end

  #---------------------------------------------------------------------------#

  # Provides support for managing a header directory. It also keeps track of
  # the header search paths.
  #
  class HeadersDirectory

    # @return [Pathname] the absolute path of this header directory.
    #
    def root
      @sandbox.root + @relative_path
    end

    # @param  [Sandbox] sandbox
    #         the sandbox that contains this header dir.
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

    #--------------------------------------#

    # @!group Life cycle

    public

    # Removes the directory as it is regenerated from scratch during each
    # installation.
    #
    # @return [void]
    #
    def prepare_for_install
      root.rmtree if root.exist?
    end

    #--------------------------------------#

    # @!group Adding headers

    public

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
    # @return [void]
    #
    def add_file(namespace_path, relative_header_path)
      namespaced_header_path = root + namespace_path
      namespaced_header_path.mkpath unless File.exist?(namespaced_header_path)
      source = (@sandbox.root + relative_header_path).relative_path_from(namespaced_header_path)
      Dir.chdir(namespaced_header_path) { FileUtils.ln_sf(source, relative_header_path.basename)}
      @search_paths << namespaced_header_path.relative_path_from(@sandbox.root)
      namespaced_header_path + relative_header_path.basename
    end

    # @todo Why this variant exits?
    #
    def add_files(namespace_path, relative_header_paths)
      relative_header_paths.map { |path| add_file(namespace_path, path) }
    end

    # @return [Array<String>] All the search paths of the header directory in
    #         xcconfig format. The paths are specified relative to the pods
    #         root with the `${PODS_ROOT}` variable.
    #
    def search_paths
      @search_paths.uniq.map { |path| "${PODS_ROOT}/#{path}" }
    end

    # Adds an header search path to the sandbox.
    #
    # @param  [Pathname] path
    #         the path tho add.
    #
    # @return [void]
    #
    # @todo Why this variant exits?
    #
    def add_search_path(path)
      @search_paths << Pathname.new(@relative_path) + path
    end
  end
end
