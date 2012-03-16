
module Pod
  class DocsGenerator
    attr_reader :pod, :specification, :target_path, :options

    def initialize(pod)
      @pod = pod
      @specification = pod.specification
      @target_path = pod.sandbox.root + "Documentation" + pod.name
      @options = pod.specification.documentation || {}
    end

    def appledoc (options)
      bin = `which appledoc`.strip
      if bin.empty?
        return
      end
      arguments = []
      arguments += options
      arguments << '--print-settings' if Config.instance.verbose?
      arguments += self.files
      Open3.popen3('appledoc', *arguments) do |i, o, e|
        if Config.instance.verbose?
          puts o.read.chomp
          puts e.read.chomp
        else
          # TODO: This is needed otherwise appledoc will not install the doc set
          # This is a work around related to poor understanding of the IO class.
          o.read
          e.read
        end
      end
    end

    def generate_appledoc_options
      project_company = @specification.authors ? @specification.authors.keys.join(', ') : 'no-company'
      options = ['--project-name', @specification.to_s,
                 '--project-company', project_company,
                 '--docset-copyright', project_company,
                 '--company-id', 'org.cocoapods',
                 '--ignore', '.m']
      options += ['--docset-desc', @specification.description] if @specification.description
      ['README.md', 'README.mdown', 'README.markdown','README'].each do |f|
        if File.file?(@pod.root + f)
          options += ['--index-desc', f]
          break
        end
      end
      options += @options[:appledoc] if @options[:appledoc]
      options

    end

    def files
      @pod.absolute_source_files
    end

    def generate(install = false)
      options = generate_appledoc_options
      options += ['--output', @target_path]
      options << '--keep-intermediate-files'
      options << '--no-create-docset' unless install
      @target_path.mkpath
      @pod.chdir do
        appledoc(options)
      end
    end

  end
end

