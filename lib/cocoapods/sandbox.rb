require 'fileutils'

module Pod
  class Sandbox
    attr_reader :root
    
    def initialize(path)
      @root = Pathname.new(path)
      @header_search_paths = []
      
      FileUtils.mkdir_p(@root)
    end
    
    def implode
      root.rmtree
    end
    
    def headers_root
      root + "Headers"
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
      @header_search_paths.uniq.map { |path| "$(PODS_ROOT)/#{path}" }
    end
    
    def prepare_for_install
      headers_root.rmtree if headers_root.exist?
    end
    
    def installed_pods
      Dir[root + "**/*.podspec"].map do |podspec|
        LocalPod.from_podspec(Pathname.new(podspec), self)
      end
    end
    
    def installed_pod_named(name)
      installed_pods.find { |pod| pod.name == name }
    end
  end
end
