module Pod
  class Downloader
    autoload :Git,        'cocoapods/downloader/git'
    autoload :Mercurial,  'cocoapods/downloader/mercurial'
    autoload :Subversion, 'cocoapods/downloader/subversion'

    extend Executable

    def self.for_pod(pod)
      options = pod.specification.source.dup
      if url = options.delete(:git)
        Git.new(pod, url, options)
      elsif url = options.delete(:hg)
        Mercurial.new(pod, url, options)
      elsif url = options.delete(:svn)
        Subversion.new(pod, url, options)
      else
        raise "Unsupported download strategy `#{options.inspect}'."
      end
    end

    attr_reader :pod, :url, :options

    def initialize(pod, url, options)
      @pod, @url, @options = pod, url, options
    end

    def clean(clean_paths = [])
      return unless clean_paths
      
      clean_paths.each do |path|
        path.rmtree
      end
    end
  end
end
