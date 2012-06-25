require 'fileutils'

module Pod
  class Sandbox
    attr_reader :root

    HEADERS_DIR = "Headers"

    def initialize(path)
      @root = Pathname.new(path)
      @header_search_paths = [HEADERS_DIR]

      FileUtils.mkdir_p(@root)
    end

    def implode
      root.rmtree
    end

    def headers_root
      root + HEADERS_DIR
    end

    def project_path
      root + "Pods.xcodeproj"
    end

    def add_header_file(namespace_path, relative_header_path)
      namespaced_header_path = headers_root + namespace_path
      namespaced_header_path.mkpath unless File.exist?(namespaced_header_path)
      source = (root + relative_header_path).relative_path_from(namespaced_header_path)
      Dir.chdir(namespaced_header_path) { FileUtils.ln_sf(source, relative_header_path.basename)}
      @header_search_paths << namespaced_header_path.relative_path_from(root)
      namespaced_header_path + relative_header_path.basename
    end

    def add_header_files(namespace_path, relative_header_paths)
      relative_header_paths.map { |path| add_header_file(namespace_path, path) }
    end

    def header_search_paths
      @header_search_paths.uniq.map { |path| "${PODS_ROOT}/#{path}" }
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
      headers_root.rmtree if headers_root.exist?
    end

    def podspec_for_name(name)
      if spec_path = Dir[root + "#{name}/*.podspec"].first
        Pathname.new(spec_path)
      elsif spec_path = Dir[root + "Local Podspecs/#{name}.podspec"].first
        Pathname.new(spec_path)
      end
    end

    def installed_pod_named(name, platform)
      if spec_path = podspec_for_name(name)
        LocalPod.from_podspec(spec_path, self, platform)
      end
    end
  end
end
