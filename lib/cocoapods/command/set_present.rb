require 'net/http'

module Pod
  class Command
    module SetPresent
      def self.options
        [
          ["--name-only", "Show only the names of the pods"],
          ["--stats",     "Show additional stats (like GitHub watchers and forks)"],
        ]
      end

      def  list
        @list
      end

      def parse_set_options(argv)
        @stats = argv.option('--stats')
        @list  = argv.option('--name-only')
      end

      def present_sets(array)
        array.each do |set|
          present_set(set)
        end
      end

      def present_set(set)
        if @list
          puts set.name
        else
          puts "--> #{set.name} (#{set.versions.reverse.join(", ")})".green
          puts_wrapped_text(set.specification.summary)

          spec = set.specification.part_of_other_pod? ? set.specification.part_of_specification : set.specification

          source = spec.source.reject {|k,_| k == :commit || k == :tag }.values.first
          puts_detail('Homepage', spec.homepage)
          puts_detail('Source', source)

          if @stats
            stats = stats(source)
            puts_detail('Watchers', stats[:watchers])
            puts_detail('Forks', stats[:forks])
          end
          puts
        end
      end

      # adapted from http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
      def puts_wrapped_text(txt, col = 80, indentation = 4)
        indent = ' ' * indentation
        puts txt.strip.gsub(/(.{1,#{col}})( +|$)\n?|(.{#{col}})/, indent + "\\1\\3\n")
      end

      def puts_detail(title,string)
        return if !string
        # 8 is the length of homepage
        number_of_spaces = ((8 - title.length) > 0) ? (8 - title.length) : 0
        spaces = ' ' * number_of_spaces
        puts "    - #{title}: #{spaces + string}"
      end

      def stats(url)
        original_url, username, reponame = *(url.match(/[:\/]([\w\-]+)\/([\w\-]+)\.git/).to_a)

        result = {}
        if original_url
          gh_response       = Net::HTTP.get('github.com', "/api/v2/json/repos/show/#{username}/#{reponame}")
          result[:watchers] = gh_response.match(/\"watchers\"\W*:\W*([0-9]+)/).to_a[1]
          result[:forks]    = gh_response.match(/\"forks\"\W*:\W*([0-9]+)/).to_a[1]
        end
        result
      end
    end
  end
end
