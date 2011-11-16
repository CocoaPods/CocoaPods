module Pod
  class Downloader
    extend Executable

    def self.for_source(pod_root, source)
      options = source.dup
      if url = options.delete(:git)
        Git.new(pod_root, url, options)
      elsif url = options.delete(:hg)
        Mercurial.new(pod_root, url, options)
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

    class Git < Downloader
      executable :git

      def download
        @pod_root.dirname.mkpath
        if @options[:tag]
          download_tag
        elsif @options[:commit]
          download_commit
        else
          download_head
        end
      end

      def download_head
        git "clone '#{@url}' '#{@pod_root}'"
      end

      def download_tag
        @pod_root.mkpath
        Dir.chdir(@pod_root) do
          git "init"
          git "remote add origin '#{@url}'"
          git "fetch origin tags/#{@options[:tag]}"
          git "reset --hard FETCH_HEAD"
          git "checkout -b activated-pod-commit"
        end
      end

      def download_commit
        git "clone '#{@url}' '#{@pod_root}'"
        Dir.chdir(@pod_root) do
          git "checkout -b activated-pod-commit #{@options[:commit]}"
        end
      end

      def clean(clean_paths = [])
        super
        (@pod_root + '.git').rmtree
      end
    end

    class Mercurial < Downloader
      extend Executable
      executable :hg

      def download
        @pod_root.dirname.mkpath
        if @options[:revision]
          download_revision
        else
          download_head
        end
      end

      def download_head
        hg "clone '#{@url}' '#{@pod_root}'"
      end

      def download_revision
        hg "clone '#{@url}' --rev '#{@options[:revision]}' '#{@pod_root}'"
      end

      def clean(clean_paths = [])
        super
        #(@pod_root + '.git').rmtree
        puts "TODO clean mercurial!"
      end
    end
  end
end
