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

      # @return [Hash<String, Hash<Symbol, String>>]
      #         A hash whose keys are the pod spec name
      #         And values are a hash with the following keys:
      #         :spec_file : path to the spec file
      #         :name      : name of the pod
      #         :version   : pod version
      #         :release   : boolean to tell if that's a release pod
      #         :slug      : the slug path where the pod cache is located
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
          @pod_name = argv.shift_argument
          @short_output = argv.flag?('short')
          super
        end

        def run
          UI.puts("Cache root: #{@cache_root}") if @short_output
          if @pod_name.nil? # Print all
            cache_info_per_pod.each do |pod, infos|
              UI.title pod
              print_pod_cache_infos(infos)
            end
          else # Print only for the requested pod
            cache_infos = cache_info_per_pod[@pod_name]
            if cache_infos.nil?
              UI.notice("No cache for pod named #{@pod_name} found")
            else
              print_pod_cache_infos(cache_infos)
            end
          end
        end

        private

        # Prints the list of specs & pod cache dirs for a single pod name
        #
        # @param [Array<Hash>] info_list
        #        The various infos about a pod cache. Keys are
        #        :spec_file, :version, :release and :slug
        #
        def print_pod_cache_infos(info_list)
          info_list.each do |info|
            UI.section("#{info[:version]} (#{pod_type(info)})") do
              if @short_output
                [:spec_file, :slug].each { |k| info[k] = info[k].relative_path_from(@cache_root) }
              end
              UI.labeled('Spec', info[:spec_file])
              UI.labeled('Pod', info[:slug])
            end
          end
        end
      end

      class Clean < Cache
        self.summary = 'Remove the cache for pods'

        self.description = <<-DESC
          Remove the cache for a given pod, or clear the cache completely.

          If there is multiple cache for various versions of the requested pod,
          you will be asked which one to clean. Use `--all` to clean them all.

          If you don't give a pod `NAME`, you need to specify the `--all`
          flag (this is to avoid cleaning all the cache by mistake).
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME', false),
        ]

        def self.options
          [[
            '--all', 'Remove all the cached pods without asking'
          ]].concat(super)
        end

        def initialize(argv)
          @pod_name = argv.shift_argument
          @wipe_all = argv.flag?('all')
          super
        end

        def run
          if @pod_name.nil? # && @wipe_all
            # Remove all
            clear_cache
          else
            # Remove only cache for this pod
            cache_list = cache_info_per_pod[@pod_name]
            if cache_list.nil?
              UI.notice("No cache for pod named #{@pod_name} found")
            elsif cache_list.count > 1 && !@wipe_all
              # Ask which to remove
              choices = cache_list.map { |c| "#{@pod_name} v#{c[:version]} (#{pod_type(c)})" }
              index = UI.choose_from_array(choices, 'Which pod cache do you want to remove?')
              remove_caches([cache_list[index]])
            else
              # Remove all found cache of this pod
              remove_caches(cache_list)
            end
          end
        end

        def validate!
          super
          if @pod_name.nil? && !@wipe_all
            # Security measure, to avoid removing the pod cache too agressively by mistake
            help! 'You should either specify a pod name or use the --all flag'
          end
        end

        private

        # Removes the specified cache
        #
        # @param [Array<Hash>] cache_infos
        #        An array of caches to remove, each specified with the same
        #        hash as cache_info_per_pod especially :spec_file and :slug
        #
        def remove_caches(cache_infos)
          cache_infos.each do |info|
            UI.message("Removing spec #{info[:spec_file]} (v#{info[:version]})")
            FileUtils.rm(info[:spec_file])
            UI.message("Removing cache #{info[:slug]}")
            FileUtils.rm_rf(info[:slug])
          end
        end

        def clear_cache
          UI.message("Removing the whole cache dir #{@cache_root}")
          FileUtils.rm_rf(@cache_root)
        end
      end
    end
  end
end
