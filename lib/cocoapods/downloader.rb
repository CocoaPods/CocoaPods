require 'cocoapods-downloader'
require 'claide/informative_error'
require 'fileutils'
require 'tmpdir'

module Pod
  module Downloader
    require 'cocoapods/downloader/cache'
    require 'cocoapods/downloader/request'
    require 'cocoapods/downloader/response'

    # Downloads a pod from the given `request` to the given `target` location.
    #
    # @return [Response] The download response for this download.
    #
    # @param  [Request] request
    #         the request that describes this pod download.
    #
    # @param  [Pathname,Nil] target
    #         the location to which this pod should be downloaded. If `nil`,
    #         then the pod will only be cached.
    #
    # @param  [Pathname,Nil] cache_path
    #         the path used to cache pod downloads. If `nil`, then no caching
    #         will be done.
    #
    def self.download(
      request,
      target,
      cache_path: !Config.instance.skip_download_cache && Config.instance.clean? && Config.instance.cache_root + 'Pods'
    )
      if cache_path
        cache = Cache.new(cache_path)
        result = cache.download_pod(request)
      else
        require 'cocoapods/installer/pod_source_preparer'
        result, _ = download_request(request, target)
        Installer::PodSourcePreparer.new(result.spec, result.location).prepare!
      end

      if target && result.location && target != result.location
        UI.message "Copying #{request.name} from `#{result.location}` to #{UI.path target}", '> ' do
          FileUtils.rm_rf target
          FileUtils.cp_r(result.location, target)
        end
      end
      result
    end

    # Performs the download from the given `request` to the given `target` location.
    #
    # @return [Response, Hash<String,Specification>]
    #         The download response for this download, and the specifications
    #         for this download grouped by name.
    #
    # @param  [Request] request
    #         the request that describes this pod download.
    #
    # @param  [Pathname,Nil] target
    #         the location to which this pod should be downloaded. If `nil`,
    #         then the pod will only be cached.
    #
    def self.download_request(request, target)
      result = Response.new
      result.checkout_options = download_source(request.name, target, request.params, request.head?)
      result.location = target

      if request.released_pod?
        result.spec = request.spec
        podspecs = { request.name => request.spec }
      else
        podspecs = Sandbox::PodspecFinder.new(target).podspecs
        podspecs[request.name] = request.spec if request.spec
        podspecs.each do |name, spec|
          if request.name == name
            result.spec = spec
          end
        end
      end

      [result, podspecs]
    end

    private

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
    def self.download_source(name, target, params, head)
      FileUtils.rm_rf(target)
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
      target.mkpath

      if downloader.options_specific? && !head
        params
      else
        downloader.checkout_options
      end
    end

    public

    class DownloaderError; include CLAide::InformativeError; end

    class Base
      override_api do
        def execute_command(executable, command, raise_on_failure = false)
          Executable.execute_command(executable, command, raise_on_failure)
        rescue CLAide::InformativeError => e
          raise DownloaderError, e.message
        end

        # Indicates that an action will be performed. The action is passed as a
        # block.
        #
        # @param  [String] message
        #         The message associated with the action.
        #
        # @yield  The action, this block is always executed.
        #
        # @return [void]
        #
        def ui_action(message)
          UI.section(" > #{message}", '', 1) do
            yield
          end
        end

        # Indicates that a minor action will be performed. The action is passed
        # as a block.
        #
        # @param  [String] message
        #         The message associated with the action.
        #
        # @yield  The action, this block is always executed.
        #
        # @return [void]
        #
        def ui_sub_action(message)
          UI.section(" > #{message}", '', 2) do
            yield
          end
        end

        # Prints an UI message.
        #
        # @param  [String] message
        #         The message associated with the action.
        #
        # @return [void]
        #
        def ui_message(message)
          UI.puts message
        end
      end
    end
  end
end
