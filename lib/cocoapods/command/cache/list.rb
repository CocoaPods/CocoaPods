module Pod
  class Command
    class Cache < Command
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
    end
  end
end
