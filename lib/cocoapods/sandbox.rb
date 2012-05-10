require 'fileutils'

module Pod
  class Sandbox
    attr_reader :root
    attr_reader :build_header_storage
    attr_reader :public_header_storage

    PUBLIC_HEADERS_DIR = "Headers"
    BUILD_HEADERS_DIR = "BuildHeaders"

    def initialize(path)
      @root = Pathname.new(path)
      @build_header_storage = HeaderStorage.new(self, BUILD_HEADERS_DIR)
      @public_header_storage = HeaderStorage.new(self, PUBLIC_HEADERS_DIR)

      FileUtils.mkdir_p(@root)
    end

    def implode
      root.rmtree
    end

    def project_path
      root + "Pods.xcodeproj"
    end

    def prepare_for_install
      build_header_storage.prepare_for_install
      public_header_storage.prepare_for_install
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
  
  class HeaderStorage
    def initialize(sandbox, base_dir)
      @sandbox = sandbox
      @base_dir = base_dir
      @search_paths = [base_dir]
    end
    
    def root
      @sandbox.root + @base_dir
    end
    
    def add_file(namespace_path, relative_header_path)
      namespaced_header_path = @sandbox.root + @base_dir + namespace_path
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
    
    def prepare_for_install
      root.rmtree if root.exist?
    end
  end
end
