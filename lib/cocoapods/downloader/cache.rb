require 'fileutils'
require 'tmpdir'

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

      # Initialize a new instance
      #
      # @param  [Pathname,String] root
      #         see {#root}
      #
      def initialize(root)
        @root = Pathname(root)
        ensure_matching_version
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
        UI.puts("\n[!] Error installing #{request.name}".red)
        raise
      end

      # @return [Hash<String, Hash<Symbol, String>>]
      #         A hash whose keys are the pod name
      #         And values are a hash with the following keys:
      #         :spec_file : path to the spec file
      #         :name      : name of the pod
      #         :version   : pod version
      #         :release   : boolean to tell if that's a release pod
      #         :slug      : the slug path where the pod cache is located
      #
      def cache_descriptors_per_pod
        specs_dir = root + 'Specs'
        release_specs_dir = specs_dir + 'Release'
        return {} unless specs_dir.exist?

        spec_paths = specs_dir.find.select { |f| f.fnmatch('*.podspec.json') }
        spec_paths.reduce({}) do |hash, spec_path|
          spec = Specification.from_file(spec_path)
          hash[spec.name] ||= []
          is_release = spec_path.to_s.start_with?(release_specs_dir.to_s)
          request = Downloader::Request.new(:spec => spec, :released => is_release)
          hash[spec.name] << {
            :spec_file => spec_path,
            :name => spec.name,
            :version => spec.version,
            :release => is_release,
            :slug => root + request.slug,
          }
          hash
        end
      end

      private

      # Ensures the cache on disk was created with the same CocoaPods version as
      # is currently running.
      #
      # @return [Void]
      #
      def ensure_matching_version
        version_file = root + 'VERSION'
        version = version_file.read.strip if version_file.file?

        root.rmtree if version != Pod::VERSION && root.exist?
        root.mkpath

        version_file.open('w') { |f| f << Pod::VERSION }
      end

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
        cached_spec = cached_spec(request)
        path = path_for_pod(request)

        return unless cached_spec && path.directory?
        spec = request.spec || cached_spec
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
      rescue JSON::ParserError
        nil
      end

      # @param  [Request] request
      #         the request to be downloaded.
      #
      # @return [Response] The download response for the given `request` that
      #         was not found in the download cache.
      #
      def uncached_pod(request)
        in_tmpdir do |target|
          result, podspecs = download(request, target)
          result.location = nil

          podspecs.each do |name, spec|
            destination = path_for_pod(request, :name => name, :params => result.checkout_options)
            copy_and_clean(target, destination, spec)
            write_spec(spec, path_for_spec(request, :name => name, :params => result.checkout_options))
            if request.name == name
              result.location = destination
            end
          end

          result
        end
      end

      def download(request, target)
        Downloader.download_request(request, target)
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
        FileUtils.remove_entry(tmpdir) if tmpdir && tmpdir.exist?
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
        specs_by_platform = group_subspecs_by_platform(spec)
        destination.parent.mkpath
        FileUtils.rm_rf(destination)
        FileUtils.cp_r(source, destination)
        Pod::Installer::PodSourcePreparer.new(spec, destination).prepare!
        Sandbox::PodDirCleaner.new(destination, specs_by_platform).clean!
      end

      def group_subspecs_by_platform(spec)
        specs_by_platform = {}
        [spec, *spec.recursive_subspecs].each do |ss|
          ss.available_platforms.each do |platform|
            specs_by_platform[platform] ||= []
            specs_by_platform[platform] << ss
          end
        end
        specs_by_platform
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
    end
  end
end
