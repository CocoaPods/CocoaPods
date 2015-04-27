require 'fileutils'
require 'tmpdir'

require 'cocoapods/executable'

module Pod
  module Downloader
    # The class responsible for managing Pod downloads, transparently caching
    # them in a cache directory.
    #
    class Cache
      # @return [Pathname] The root directory where this cache store its
      #         downloads.
      #
      attr_reader :root

      # @param  [Pathname,String] root
      #         see {#root}
      #
      def initialize(root)
        @root = Pathname(root)
        @root.mkpath
      end

      # Downloads the Pod from the given `request`
      #
      # @param  [Request] request
      #         the request to be downloaded.
      #
      # @return [Response] the response from downloading `request`
      #
      def download_pod(request)
        cached_pod(request) || uncached_pod(request)
      rescue Informative
        raise
      rescue
        UI.notice("Error installing #{request.name}")
        raise
      end

      private

      # @param  [Request] request
      #         the request to be downloaded.
      #
      # @param  [Hash<Symbol,String>] slug_opts
      #         the download options that should be used in constructing the
      #         cache slug for this request.
      #
      # @return [Pathname] The path for the Pod downloaded from the given
      #         `request`.
      #
      def path_for_pod(request, slug_opts = {})
        root + request.slug(slug_opts)
      end

      # @param  [Request] request
      #         the request to be downloaded.
      #
      # @param  [Hash<Symbol,String>] slug_opts
      #         the download options that should be used in constructing the
      #         cache slug for this request.
      #
      # @return [Pathname] The path for the podspec downloaded from the given
      #         `request`.
      #
      def path_for_spec(request, slug_opts = {})
        path = root + 'Specs' + request.slug(slug_opts)
        path.sub_ext('.podspec.json')
      end

      # @param  [Request] request
      #         the request to be downloaded.
      #
      # @return [Response] The download response for the given `request` that
      #         was found in the download cache.
      #
      def cached_pod(request)
        path = path_for_pod(request)
        spec = request.spec || cached_spec(request)
        return unless spec && path.directory?
        Response.new(path, spec, request.params)
      end

      # @param  [Request] request
      #         the request to be downloaded.
      #
      # @return [Specification] The cached specification for the given
      #         `request`.
      #
      def cached_spec(request)
        path = path_for_spec(request)
        path.file? && Specification.from_file(path)
      end

      # @param  [Request] request
      #         the request to be downloaded.
      #
      # @return [Response] The download response for the given `request` that
      #         was not found in the download cache.
      #
      def uncached_pod(request)
        in_tmpdir do |target|
          result = Response.new
          result.checkout_options = download(request.name, target, request.params, request.head?)

          if request.released_pod?
            result.spec = request.spec
            result.location = destination = path_for_pod(request, :params => result.checkout_options)
            copy_and_clean(target, destination, request.spec)
            write_spec(request.spec, path_for_spec(request, :params => result.checkout_options))
          else
            podspecs = Sandbox::PodspecFinder.new(target).podspecs
            podspecs[request.name] = request.spec if request.spec
            podspecs.each do |name, spec|
              destination = path_for_pod(request, :name => name, :params => result.checkout_options)
              copy_and_clean(target, destination, spec)
              write_spec(spec, path_for_spec(request, :name => name, :params => result.checkout_options))
              if request.name == name
                result.location = destination
                result.spec = spec
              end
            end
          end

          result
        end
      end

      # Downloads a pod with the given `name` and `params` to `target`.
      #
      # @param  [String] name
      #
      # @param  [Pathname] target
      #
      # @param  [Hash<Symbol,String>] params
      #
      # @param  [Boolean] head
      #
      # @return [Hash] The checkout options required to re-download this exact
      #         same source.
      #
      def download(name, target, params, head)
        downloader = Downloader.for_target(target, params)
        if head
          unless downloader.head_supported?
            raise Informative, "The pod '#{name}' does not " \
              "support the :head option, as it uses a #{downloader.name} " \
              'source. Remove that option to use this pod.'
          end
          downloader.download_head
        else
          downloader.download
        end

        if downloader.options_specific? && !head
          params
        else
          downloader.checkout_options
        end
      end

      # Performs the given block inside a temporary directory,
      # which is removed at the end of the block's scope.
      #
      # @return [Object] The return value of the given block
      #
      def in_tmpdir(&blk)
        tmpdir = Pathname(Dir.mktmpdir)
        blk.call(tmpdir)
      ensure
        FileUtils.remove_entry(tmpdir) if tmpdir.exist?
      end

      # Copies the `source` directory to `destination`, cleaning the directory
      # of any files unused by `spec`.
      #
      # @param  [Pathname] source
      #
      # @param  [Pathname] destination
      #
      # @param  [Specification] spec
      #
      # @return [Void]
      #
      def copy_and_clean(source, destination, spec)
        specs_by_platform = {}
        spec.available_platforms.each do |platform|
          specs_by_platform[platform] = [spec, *spec.recursive_subspecs].select { |ss| ss.supported_on_platform?(platform) }
        end
        destination.parent.mkpath
        FileUtils.cp_r(source, destination)
        run_prepare_command(spec, destination)
        Sandbox::PodDirCleaner.new(destination, specs_by_platform).clean!
      end

      # Writes the given `spec` to the given `path`.
      #
      # @param  [Specification] spec
      #         the specification to be written.
      #
      # @param  [Pathname] path
      #         the path the specification is to be written to.
      #
      # @return [Void]
      #
      def write_spec(spec, path)
        path.dirname.mkpath
        path.open('w') { |f| f.write spec.to_pretty_json }
      end

      extend Executable
      executable :bash

      # Runs the prepare command bash script of the spec.
      #
      # @note   Unsets the `CDPATH` env variable before running the
      #         shell script to avoid issues with relative paths
      #         (issue #1694).
      #
      # @return [void]
      #
      def run_prepare_command(spec, root)
        return unless spec.prepare_command
        UI.section(' > Running prepare command', '', 1) do
          Dir.chdir(root) do
            ENV.delete('CDPATH')
            prepare_command = spec.prepare_command.strip_heredoc.chomp
            full_command = "\nset -e\n" + prepare_command
            bash!('-c', full_command)
          end
        end
      end
    end
  end
end
