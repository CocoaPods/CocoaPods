module Pod
  class LocalPod
    attr_reader :specification
    
    def initialize(specification, sandbox)
      @specification, @sandbox = specification, sandbox
    end
    
    def root
      @sandbox.root + specification.name
    end
    
    def create
      root.mkpath unless root.exist?
    end
    
    def chdir(&block)
      create
      Dir.chdir(root, &block)
    end
    
    def implode
      root.rmtree if root.exist?
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
    
    private
    
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
