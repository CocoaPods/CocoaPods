require 'cocoapods/downloader'

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

      # @return [Hash<String, Hash<String, Request>>]
      #         A hash whose keys are the pod spec name
      #         And values are a hash keyed by the specs file paths
      #
      def cache_requests_per_pod
        specs_dir = @cache_root + 'Specs'
        spec_files = specs_dir.find.select { |f| f.fnmatch('*.podspec.json') }
        spec_files.reduce({}) do |hash, spec_file|
          spec = Specification.from_file(spec_file)
          hash[spec.name] = {} if hash[spec.name].nil?
          release = spec_file.to_s.start_with?((specs_dir + 'Release').to_s)
          request = Downloader::Request.new(:spec => spec, :released => release)
          hash[spec.name][spec_file] = request
          hash
        end
      end

      class List < Cache
        self.summary = 'List the paths of pod caches for each known pod'

        self.description = <<-DESC
          Shows the content of cache organized by pod.
          If `NAME` is given, show the results only for that pod name.
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME', false),
        ]

        def self.options
          [[
            '--short', 'Only print the path relative to the cache root'
          ]].concat(super)
        end

        def initialize(argv)
          @podname = argv.shift_argument
          @short_output = argv.flag?('short')
          super
        end

        def run
          UI.puts("Cache root: #{@cache_root}") if @short_output
          if @podname.nil? # Print all
            cache_requests_per_pod.each do |pod, list|
              UI.title pod
              print_pod_cache_list(list)
            end
          else # Print only for the requested pod
            cache_list = cache_requests_per_pod[@podname]
            if cache_list.nil?
              UI.notice("No cache for pod named #{@podname} found")
            else
              print_pod_cache_list(cache_list)
            end
          end
        end

        private

        # Prints the list of specs & pod cache dirs for a single pod name
        #
        # @param [Hash<String,Request>] list
        #        The list of spec_file => Downloader::Request
        #        for a given pod name
        #
        def print_pod_cache_list(list)
          list.each do |spec_file, request|
            type = request.released_pod? ? 'Release' : 'External'
            UI.section("#{request.spec.version} (#{type})") do
              UI.labeled('Spec', @short_output ? spec_file.relative_path_from(@cache_root) : spec_file)
              UI.labeled('Pod', @short_output ? request.slug : @cache_root + request.slug)
            end
          end
        end
      end
    end
  end
end
