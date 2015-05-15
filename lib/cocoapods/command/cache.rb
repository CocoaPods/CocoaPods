require 'cocoapods/downloader'
require 'cocoapods/command/cache/list'
require 'cocoapods/command/cache/clean'

module Pod
  class Command
    class Cache < Command
      self.abstract_command = true
      self.summary = 'Manipulate the CocoaPods cache'

      self.description = <<-DESC
        Manipulate the download cache for pods, like printing the cache content
        or cleaning the pods cache.
      DESC

      def initialize(argv)
        @cache_root = Config.instance.cache_root + 'Pods'
        super
      end

      private

      # @return [Hash<String, Hash<Symbol, String>>]
      #         A hash whose keys are the pod spec name
      #         And values are a hash with the following keys:
      #         :spec_file : path to the spec file
      #         :name      : name of the pod
      #         :version   : pod version
      #         :release   : boolean to tell if that's a release pod
      #         :slug      : the slug path where the pod cache is located
      #
      # @todo Move this to Pod::Downloader::Cache
      #
      def cache_info_per_pod
        specs_dir = @cache_root + 'Specs'
        spec_files = specs_dir.find.select { |f| f.fnmatch('*.podspec.json') }
        spec_files.reduce({}) do |hash, spec_file|
          spec = Specification.from_file(spec_file)
          hash[spec.name] = [] if hash[spec.name].nil?
          is_release = spec_file.to_s.start_with?((specs_dir + 'Release').to_s)
          request = Downloader::Request.new(:spec => spec, :released => is_release)
          hash[spec.name] << {
            :spec_file => spec_file,
            :version => request.spec.version,
            :release => is_release,
            :slug => @cache_root + request.slug,
          }
          hash
        end
      end

      def pod_type(pod_cache_info)
        pod_cache_info[:release] ? 'Release' : 'External'
      end
    end
  end
end
