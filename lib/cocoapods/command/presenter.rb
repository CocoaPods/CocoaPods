module Pod
  class Command
    class Presenter
      def self.options
        "    --stats     Show additional stats (like GitHub watchers and forks)\n"
      end

      autoload :CocoaPod, 'cocoapods/command/presenter/cocoa_pod'

      def initialize(argv)
        @stats = argv.option('--stats')
      end

      def render(array)
        result = "\n"
        seats.each {|s| puts describe(s)}
        result
      end

      def describe(set)
        pod = CocoaPod.new(set)
        result = "\n--> #{pod.name} (#{pod.versions})\n".green
        result << wrap_string(pod.summary)
        result << detail('Homepage', pod.homepage)
        result << detail('Source',   pod.source_url)
        if @stats
          result << detail('Authors',  pod.authors) if pod.authors =~ /,/
          result << detail('Author',   pod.authors) if pod.authors !~ /,/
          result << detail('Platform', pod.platform)
          result << detail('License',  pod.license)
          result << detail('Watchers', pod.github_watchers)
          result << detail('Forks',    pod.github_forks)
        end
        result << detail('Sub specs', pod.subspecs)
        result
      end

      private

      # adapted from http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
      def wrap_string(txt, col = 80, indentation = 4)
        indent = ' ' * indentation
        txt.strip.gsub(/(.{1,#{col}})( +|$)\n?|(.{#{col}})/, indent + "\\1\\3\n")
      end

      def detail(title, value, preferred_indentation = 8)
        # 8 is the length of Homepage
        return '' if !value
        number_of_spaces = ((preferred_indentation - title.length) > 0) ? (preferred_indentation - title.length) : 0
        spaces = ' ' * number_of_spaces
        ''.tap do |t|
          t << "    - #{title}:"
          if value.class == Array
            separator = "\n      - "
            t << separator + value.join(separator)
          else
            t << " #{spaces + value.to_s}\n"
          end
        end
      end
    end
  end
end
