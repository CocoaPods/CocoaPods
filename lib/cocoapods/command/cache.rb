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

      class List < Cache
        self.summary = 'List the paths of pod caches for each known pod'

        self.description = <<-DESC
          Shows the content of cache organized by pod.
          If `NAME` is given, show the results only for that pod name.
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME', false),
        ]

        def initialize(argv)
          @podname = argv.shift_argument
          @cache_root = Config.instance.cache_root + 'Pods'
          super
        end


        def run
          if (@podname.nil?)
            cache_hash.each do |pod, list|
              UI.title pod
              print_pod_cache_list(list)
            end
          else
            cache_list = cache_hash[@podname]
            if cache_list.nil?
              UI.notice("No cache for pod named #{@podname} found")
            else
              print_pod_cache_list(cache_list)
            end
          end
        end

        private

        def print_pod_cache_list(list)
          list.each do |spec_file, request|
            type = request.released_pod? ? 'Release' : 'External'
            UI.section("#{request.spec.version} (#{type})") do
              UI.labeled('Spec', spec_file)
              UI.labeled('Pod', @cache_root+request.slug)
            end
          end
        end

        def cache_hash
          specs_dir = @cache_root + 'Specs'
          spec_files = specs_dir.find.select { |f| f.fnmatch('*.podspec.json') }
          spec_files.reduce({}) do |hash, spec_file|
            spec = Specification.from_file(spec_file)
            hash[spec.name] = {} if hash[spec.name].nil?
            release = spec_file.to_s.start_with? (specs_dir + 'Release').to_s
            request = Downloader::Request.new(:spec => spec, :released => release)
            hash[spec.name][spec_file] = request
            hash
          end
        end
      end

    end
  end
end
