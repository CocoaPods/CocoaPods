module Pod
  class Downloader
    def self.for_source(source, pod_root)
      options = source.dup
      if url = options.delete(:git)
        Git.new(pod_root, url, options)
      else
        raise "Unsupported download strategy `#{source.inspect}'."
      end
    end

    def initialize(pod_root, url, options)
      @pod_root, @url, @options = pod_root, url, options
    end

    class Git < Downloader
      require 'rubygems'
      require 'executioner'
      include Executioner
      # TODO make Executioner:
      # * not raise when there's output to either stdout/stderr, but check exit status
      # * sync output
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
          git "fetch origin tags/#{@options[:tag]} 2>&1"
          git "reset --hard FETCH_HEAD"
          git "checkout -b activated-pod-commit 2>&1"
        end
      end

      def download_commit
        git "clone '#{@url}' '#{@pod_root}'"
        Dir.chdir(@pod_root) do
          git "checkout -b activated-pod-commit #{@options[:commit]} 2>&1"
        end
      end

      def clean
        (@pod_root + '.git').rmtree
      end
    end
  end
end
