module Pod
  class Downloader
    def self.for_source(pod_root, source)
      options = source.dup
      if url = options.delete(:git)
        Git.new(pod_root, url, options)
      else
        raise "Unsupported download strategy `#{source.inspect}'."
      end
    end

    attr_reader :pod_root, :url, :options

    def initialize(pod_root, url, options)
      @pod_root, @url, @options = pod_root, url, options
    end

    class Git < Downloader
      extend Executable
      executable :git

      def download
        if @options[:tag]
          download_tag
        elsif @options[:commit]
          download_commit
        else
          raise "Either a tag or a commit has to be specified."
        end
      end

      def download_tag
        @pod_root.mkdir
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

      def clean
        (@pod_root + '.git').rmtree
      end
    end
  end
end
