module Pod
  class UserInterface
    @indentation_level =  0
    @title_level       =  0
    @title_colors      =  %w|yellow green|

    class << self
      include Config::Mixin

      attr_accessor :indentation_level, :title_level

      def title(title, verbose_prefix = '', relative_indentation = 2)
        if config.verbose?
          title = verbose_prefix + title if config.verbose?
          title = "\n#{title}" if @title_level < 2
          if (color = @title_colors[@title_level])
            title = title.send(color)
          end
          puts "#{title}"
        elsif title_level < 2
          puts title
        end

        self.indentation_level += relative_indentation
        self.title_level += 1
        yield if block_given?
        self.indentation_level -= relative_indentation
        self.title_level -= 1
      end

      def message(message,  verbose_prefix = '', relative_indentation = 2)
        message = verbose_prefix + message if config.verbose?
        puts_indented message if config.verbose?

        self.indentation_level += relative_indentation
        yield if block_given?
        self.indentation_level -= relative_indentation
      end

      def puts(message)
        super(message) unless config.silent?
      end

      def puts_indented(message)
        indented = wrap_string(message, " " * indentation_level)
        puts(indented)
      end

      def path(pathname)
        if pathname
          "`./#{pathname.relative_path_from(config.project_podfile.dirname || Pathname.pwd)}'"
        else
          ''
        end
      end

      # adapted from http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
      def wrap_string(txt, indent)
        width = `stty size`.split(' ')[1].to_i - indent.length
        txt.strip.gsub(/(.{1,#{width}})( +|$)\n?|(.{#{width}})/, indent + "\\1\\3\n")
      end
    end
  end
  UI = UserInterface
end
