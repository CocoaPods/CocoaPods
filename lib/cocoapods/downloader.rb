module Pod
  class Downloader
    autoload :Git,        'cocoapods/downloader/git'
    autoload :Mercurial,  'cocoapods/downloader/mercurial'
    autoload :Subversion, 'cocoapods/downloader/subversion'

    extend Executable

    def self.for_source(pod_root, source)
      options = source.dup
      if url = options.delete(:git)
        Git.new(pod_root, url, options)
      elsif url = options.delete(:hg)
        Mercurial.new(pod_root, url, options)
      elsif url = options.delete(:svn)
        Subversion.new(pod_root, url, options)
      else
        raise "Unsupported download strategy `#{source.inspect}'."
      end
    end

    attr_reader :pod_root, :url, :options

    def initialize(pod_root, url, options)
      @pod_root, @url, @options = pod_root, url, options
    end

    def clean(clean_paths = [])
      clean_paths.each do |path|
        path.rmtree
      end if clean_paths
    end
  end
end
