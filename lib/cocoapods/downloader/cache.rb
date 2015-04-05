require 'fileutils'
require 'tmpdir'

module Pod
  module Downloader
    class Cache

      attr_reader :root

      def initialize(root)
        @root = root
        root.mkpath unless root.exist?
      end

      def download_pod(request)
        cached_pod(request) || uncached_pod(request)
      rescue Informative
        raise
      rescue
        UI.notice("Error installing #{request.name}")
        raise
      end

      private

      # @return [Pathname] The path for the Pod downloaded from the given
      #         `request`.
      #
      def path_for_pod(request, slug_opts = {})
        root + request.slug(slug_opts)
      end

      # @return [Pathname] The path for the podspec downloaded from the given
      #         `request`.
      #
      def path_for_spec(request, slug_opts = {})
        path = root + 'Specs' + request.slug(slug_opts)
        path.sub_ext('.podspec.json')
      end

      def cached_pod(request)
        path = path_for_pod(request)
        spec = request.spec || cached_spec(request)
        return unless spec && path.directory?
        Response.new(path, spec, request.params)
      end

      def cached_spec(request)
        path = path_for_spec(request)
        path.file? && Specification.from_file(path)
      end

      def uncached_pod(request)
        in_tmpdir do |target|
          result = Response.new
          result.checkout_options = download(request.name, target, request.params, request.head?)

          if request.released_pod?
            result.location = destination = path_for_pod(request, :params => result.checkout_options)
            copy_and_clean(target, destination, request.spec)
            write_spec(request.spec, path_for_spec(request, :params => result.checkout_options))
          else
            podspecs = Sandbox::PodspecFinder.new(target).podspecs
            podspecs[request.name] = request.spec if request.spec
            podspecs.each do |_, spec|
              destination = path_for_pod(request, :name => spec.name, :params => result.checkout_options)
              copy_and_clean(target, destination, spec)
              write_spec(spec, path_for_spec(request, :name => spec.name, :params => result.checkout_options))
              if request.name == spec.name
                result.location = destination
                result.spec = spec
              end
            end
          end

          result
        end
      end

      def download(name, target, params, head)
        downloader = Downloader.for_target(target, params)
        if head
          unless downloader.head_supported?
            raise Informative, "The pod '" + name + "' does not " \
              'support the :head option, as it uses a ' + downloader.name +
              ' source. Remove that option to use this pod.'
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

      def in_tmpdir(&blk)
        tmpdir = Pathname(Dir.mktmpdir)
        blk.call(tmpdir)
      ensure
        FileUtils.remove_entry(tmpdir) if tmpdir.exist?
      end

      def copy_and_clean(source, destination, spec)
        specs_by_platform = {}
        spec.available_platforms.each do |platform|
          specs_by_platform[platform] = [spec, *spec.recursive_subspecs].select { |ss| ss.supported_on_platform?(platform) }
        end
        destination.parent.mkpath unless destination.parent.exist?
        FileUtils.cp_r(source, destination)
        Sandbox::PodDirCleaner.new(destination, specs_by_platform).clean!
      end

      def write_spec(spec, path)
        FileUtils.mkdir_p path.dirname
        path.open('w') { |f| f.write spec.to_pretty_json }
      end
    end
  end
end
