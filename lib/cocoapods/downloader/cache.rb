require 'fileutils'
require 'tmpdir'

module Pod
  module Downloader
    class Cache
      class MockSandbox
        attr_accessor :spec, :target, :checkout_options

        def initialize(target)
          @target = target
          @specs = []
        end

        def pod_dir(_name)
          target
        end

        def store_podspec(_name, podspec, _external_source = false, json = false)
          if podspec.is_a? String
            podspec = Specification.from_string(podspec, "pod.podspec#{'.json' if json}")
          elsif podspec.is_a? Pathname
            podspec = Specification.from_file(podspec)
          end
          spec = podspec
        end

        def store_pre_downloaded_pod(*_); end

        def store_checkout_source(_name, source)
          checkout_options = source
        end

        def local?(_); false end
      end

      attr_accessor :root

      def initialize(root)
        @root = root
        root.mkpath unless root.exist?
      end

      def cache_key(pod_name, version = nil, downloader_opts = nil)
        raise ArgumentError unless pod_name || (!version && !downloader_opts)
        pod_name =

        if version
          "Release/#{pod_name}/#{version}"
        elsif downloader_opts
          opts = downloader_opts.to_a.sort_by(&:first).map { |k, v| "#{k}=#{v}" }.join('-')
          "External/#{pod_name}/#{opts}"
        end
      end

      def path_for_pod(name, version = nil, downloader_opts = nil)
        root + cache_key(name, version, downloader_opts)
      end

      def download_pod(name_or_spec, downloader_opts = nil, head = false)
        if name_or_spec.is_a? Pod::Specification
          spec = name_or_spec.root
          name, version, downloader_opts = spec.name, spec.version, spec.source.dup
        else
          name = Specification.root_name(name_or_spec.to_s)
        end

        destination = path_for_pod(name, version, downloader_opts)
        return destination if destination.directory? && !head

        source = ExternalSources::DownloaderSource.new(name, downloader_opts, nil)

        Dir.mktmpdir do |tmpdir|
          tmpdir = Pathname(tmpdir)
          mock_sandbox = MockSandbox.new(tmpdir)
          source.fetch(mock_sandbox)
          if spec
            destination = path_for_pod(name, version)
          else
            spec = mock_sandbox.spec
            checkout_options = mock_sandbox.checkout_options
            destination = path_for_pod(found_spec.name, nil, mock_sandbox.checkout_options)
          end

          copy_and_clean(tmpdir, destination, spec)
          FileUtils.touch(tmpdir)

          [destination, checkout_options]
        end
      end

      def copy_and_clean(source, destination, spec)
        specs_by_platform = {}
        spec.available_platforms.each do |platform|
          specs_by_platform[platform] = spec.recursive_subspecs.select { |ss| ss.supported_on_platform?(platform) }
        end
        Cleaner.new(source, specs_by_platform).clean!
        destination.parent.mkpath unless destination.parent.exist?
        FileUtils.move(source, destination)
      end

    end
  end
end
