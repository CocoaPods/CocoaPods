module Pod
  class Downloader
    def self.for_source(source)
      options = source.dup
      if url = options.delete(:git)
        Git.new(url, options)
      else
        raise "Unsupported download strategy `#{source.inspect}'."
      end
    end

    def initialize(url, options)
      @url, @options = url, options
    end

    class Git < Downloader
      require 'rubygems'
      require 'executioner'
      include Executioner
      # TODO make Executioner:
      # * not raise when there's output to either stdout/stderr, but check exit status
      # * sync output
      executable :git

      def download_to(pod_root)
        checkout = pod_root + 'source'
        if tag = @options[:tag]
          checkout.mkdir
          Dir.chdir(checkout) do
            git "init"
            git "remote add origin '#{@url}'"
            git "fetch origin tags/#{tag} 2>&1"
            git "reset --hard FETCH_HEAD"
            git "checkout -b activated-pod-commit 2>&1"
          end
        elsif commit = @options[:commit]
          git "clone '#{@url}' '#{checkout}'"
          Dir.chdir(checkout) do
            git "checkout -b activated-pod-commit #{commit} 2>&1"
          end
        else
          raise "Either a tag or a commit has to be specified."
        end
      end
    end
  end
end
