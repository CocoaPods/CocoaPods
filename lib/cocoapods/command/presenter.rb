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
        array.each {|set| result << render_set(set)}
        result
      end

      def render_set(set)
        pod = CocoaPod.new(set)
        result = "--> #{pod.name} (#{pod.versions})\n".green
        result << wrap_string(pod.summary)
        result << detail('Homepage', pod.homepage)
        result << detail('Source',   pod.source_url)
        result << detail('Authors',  pod.authors)         if @stats && pod.authors =~ /,/
        result << detail('Author',   pod.authors)         if @stats && pod.authors !~ /,/
        result << detail('Platform', pod.platform)        if @stats
        result << detail('License',  pod.license)         if @stats
        result << detail('Watchers', pod.github_watchers) if @stats
        result << detail('Forks',    pod.github_forks)    if @stats
        result << "\n"
      end

      private

      # adapted from http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
      def wrap_string(txt, col = 80, indentation = 4)
        indent = ' ' * indentation
        txt.strip.gsub(/(.{1,#{col}})( +|$)\n?|(.{#{col}})/, indent + "\\1\\3\n")
      end

      def detail(title, string, preferred_indentation = 8)
        # 8 is the length of Homepage
        return '' if !string
        number_of_spaces = ((preferred_indentation - title.length) > 0) ? (preferred_indentation - title.length) : 0
        spaces = ' ' * number_of_spaces
        "    - #{title}: #{spaces + string}\n"
      end
    end
  end
end
