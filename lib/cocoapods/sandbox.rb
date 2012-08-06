require 'fileutils'

module Pod
  class Sandbox
    attr_reader :root
    attr_reader :build_headers
    attr_reader :public_headers

    BUILD_HEADERS_DIR = "BuildHeaders"
    PUBLIC_HEADERS_DIR = "Headers"

    def initialize(path)
      @root = Pathname.new(path)
      @build_headers = HeadersDirectory.new(self, BUILD_HEADERS_DIR)
      @public_headers = HeadersDirectory.new(self, PUBLIC_HEADERS_DIR)
      @cached_local_pods = {}
      FileUtils.mkdir_p(@root)
    end

    def implode
      root.rmtree
    end

    def project_path
      root + "Pods.xcodeproj"
    end

    def prepare_for_install
      build_headers.prepare_for_install
      public_headers.prepare_for_install
    end

    def local_pod_for_spec(spec, platform)
      key = [spec.top_level_parent.name, platform.to_sym]
      (@cached_local_pods[key] ||= LocalPod.new(spec.top_level_parent, self, platform)).tap do |pod|
        pod.add_specification(spec)
      end
    end

    def installed_pod_named(name, platform)
      if spec_path = podspec_for_name(name)
        key = [name, platform.to_sym]
        @cached_local_pods[key] ||= LocalPod.from_podspec(spec_path, self, platform)
      end
    end

    def podspec_for_name(name)
      if spec_path = Dir[root + "#{name}/*.podspec"].first
        Pathname.new(spec_path)
      elsif spec_path = Dir[root + "Local Podspecs/#{name}.podspec"].first
        Pathname.new(spec_path)
      end
    end
  end

  class HeadersDirectory
    def initialize(sandbox, base_dir)
      @sandbox = sandbox
      @base_dir = base_dir
      @search_paths = [base_dir]
    end

    def root
      @sandbox.root + @base_dir
    end

    def add_file(namespace_path, relative_header_path)
      namespaced_header_path = root + namespace_path
      namespaced_header_path.mkpath unless File.exist?(namespaced_header_path)
      source = (@sandbox.root + relative_header_path).relative_path_from(namespaced_header_path)
      Dir.chdir(namespaced_header_path) { FileUtils.ln_sf(source, relative_header_path.basename)}
      @search_paths << namespaced_header_path.relative_path_from(@sandbox.root)
      namespaced_header_path + relative_header_path.basename
    end

    def add_files(namespace_path, relative_header_paths)
      relative_header_paths.map { |path| add_file(namespace_path, path) }
    end

    def search_paths
      @search_paths.uniq.map { |path| "${PODS_ROOT}/#{path}" }
    end

    # Adds an header search path to the sandbox.
    #
    # @param path [Pathname] The path tho add.
    #
    # @return [void]
    #
    def add_header_search_path(path)
      @header_search_paths << Pathname.new(HEADERS_DIR) + path
    end

    def prepare_for_install
      root.rmtree if root.exist?
    end
  end
end
