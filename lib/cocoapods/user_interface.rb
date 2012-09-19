module Pod
  require 'colored'
  class UserInterface

    autoload :UIPod, 'cocoapods/user_interface/ui_pod'

    @indentation_level =  0
    @title_level       =  0
    @title_colors      =  %w|yellow green|

    class << self
      include Config::Mixin

      attr_accessor :indentation_level, :title_level

      # Prints a title taking an optional verbose prefix and
      # a relative indentation valid for the UI action in the passed
      # block.
      #
      # In verbose mode titles are printed with a color according
      # to their level. In normal mode titles are printed only if
      # they have nesting level smaller than 2.
      #
      # TODO: refactor to title (for always visible titles like search)
      # and sections (titles that reppresent collapsible sections).
      #
      def section(title, verbose_prefix = '', relative_indentation = 2)
        if config.verbose?
          title(title, verbose_prefix, relative_indentation)
        elsif title_level < 2
          puts title
        end

        self.indentation_level += relative_indentation
        self.title_level += 1
        yield if block_given?
        self.indentation_level -= relative_indentation
        self.title_level -= 1
      end

      # A title oposed to a section is always visible
      #
      def title(title, verbose_prefix = '', relative_indentation = 2)
        title = verbose_prefix + title if config.verbose?
        title = "\n#{title}" if @title_level < 2
        if (color = @title_colors[@title_level])
          title = title.send(color)
        end
        puts "#{title}"

        self.indentation_level += relative_indentation
        self.title_level += 1
        yield if block_given?
        self.indentation_level -= relative_indentation
        self.title_level -= 1
      end

      # def title(title, verbose_prefix = '', relative_indentation = 2)
      # end

      # Prints a verbose message taking an optional verbose prefix and
      # a relative indentation valid for the UI action in the passed
      # block.
      #
      # TODO: clean interface.
      #
      def message(message,  verbose_prefix = '', relative_indentation = 2)
        message = verbose_prefix + message if config.verbose?
        puts_indented message if config.verbose?

        self.indentation_level += relative_indentation
        yield if block_given?
        self.indentation_level -= relative_indentation
      end

      # Prints a message unless config is silent.
      #
      def puts(message = '')
        super(message) unless config.silent?
      end

      # Prints a message respecting the current indentation level and
      # wrapping it to the termina width if necessary.
      #
      def puts_indented(message = '')
        indented = wrap_string(message, " " * self.indentation_level)
        puts(indented)
      end

      # Returns a string containing relative location of a path from the Podfile.
      # The returned path is quoted. If the argument is nit it returns the
      # empty string.
      #
      def path(pathname)
        if pathname
          "`./#{pathname.relative_path_from(config.project_podfile.dirname || Pathname.pwd)}'"
        else
          ''
        end
      end

      # Prints the textual repprensentation of a given set.
      #
      def pod(set, mode = :normal)
        if mode == :name
          puts_indented set.name
        else
        pod = UIPod.new(set)
        title("\n-> #{pod.name} (#{pod.version})".green, '', 3) do
          puts_indented pod.summary
          labeled('Homepage', pod.homepage)
          labeled('Source',   pod.source_url)
          labeled('Versions', pod.versions) unless set.versions.count == 1
          if mode == :stats
            labeled('Pushed',   pod.github_last_activity)
            labeled('Authors',  pod.authors) if pod.authors =~ /,/
            labeled('Author',   pod.authors) if pod.authors !~ /,/
            labeled('License',  pod.license)
            labeled('Platform', pod.platform)
            labeled('Watchers', pod.github_watchers)
            labeled('Forks',    pod.github_forks)
          end
          labeled('Sub specs', pod.subspecs)
        end
        end
      end

      # Prints a message with a label.
      #
      def labeled(label, value)
        if value
          ''.tap do |t|
            t << "    - #{label}:".ljust(16)
            if value.is_a?(Array)
              separator = "\n      - "
              puts_indented t << separator << value.join(separator)
            else
              puts_indented t << value.to_s << "\n"
            end
          end
        end
      end

      # Wraps a string with a given indent to the width of the terminal.
      # adapted from http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
      #
      def wrap_string(txt, indent = '')
        width = `stty size`.split(' ')[1].to_i - indent.length
        txt.strip.gsub(/(.{1,#{width}})( +|$)\n?|(.{#{width}})/, indent + "\\1\\3\n")
      end
    end
  end
  UI = UserInterface
end
