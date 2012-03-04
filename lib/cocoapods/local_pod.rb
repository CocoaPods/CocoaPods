module Pod
  class LocalPod
    attr_reader :specification
    
    def initialize(specification, sandbox)
      @specification, @sandbox = specification, sandbox
    end
    
    def self.from_podspec(podspec, sandbox)
      new(Specification.from_file(podspec), sandbox)
    end
    
    def root
      @sandbox.root + specification.name
    end
    
    def to_s
      if specification.local?
        "#{specification} [LOCAL]"
      else
        specification.to_s
      end
    end
    
    def name
      specification.name
    end
    
    def create
      root.mkpath unless exists?
    end
    
    def exists?
      root.exist?
    end
    
    def chdir(&block)
      create
      Dir.chdir(root, &block)
    end
    
    def implode
      root.rmtree if exists?
    end
    
    def clean
      clean_paths.each { |path| FileUtils.rm_rf(path) }
    end
    
    def source_files
      expanded_paths(specification.source_files, :glob => '*.{h,m,mm,c,cpp}', :relative_to_sandbox => true)
    end
    
    def clean_paths
      expanded_paths(specification.clean_paths)
    end
    
    def resources
      expanded_paths(specification.resources, :relative_to_sandbox => true)
    end

    def header_files
      source_files.select { |f| f.extname == '.h' }
    end
    
    def link_headers
      copy_header_mappings.each do |namespaced_path, files|
        @sandbox.add_header_files(namespaced_path, files)
      end
    end
    
    def add_to_target(target)
      implementation_files.each do |file|
        target.add_source_file(file, nil, specification.compiler_flags)
      end
    end
    
    private
    
    def implementation_files
      source_files.select { |f| f.extname != '.h' }
    end
    
    def relative_root
      root.relative_path_from(@sandbox.root)
    end
    
    def copy_header_mappings
      header_files.inject({}) do |mappings, from|
        from_without_prefix = from.relative_path_from(relative_root)
        to = specification.header_dir + specification.copy_header_mapping(from_without_prefix)
        (mappings[to.dirname] ||= []) << from
        mappings
      end
    end
    
    def expanded_paths(patterns, options={})
      patterns.map do |pattern|
        pattern = root + pattern
        
        if pattern.directory? && options[:glob]
          pattern += options[:glob]
        end
        
        pattern.glob.map do |file| 
          if options[:relative_to_sandbox]
            file.relative_path_from(@sandbox.root)
          else
            file
          end
        end
      end.flatten
    end
  end
end
