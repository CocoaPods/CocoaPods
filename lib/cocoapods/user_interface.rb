module Pod
  class UserInterface
    include Config::Mixin

    def self.instance
      @instance ||= new
    end

    def initialize
      @indentation_level = 0
      @title_level = 0
      @title_colors = %w|yellow green|
    end

    attr_accessor :indentation_level, :title_level

    def title(title, verbose_prefix = '')
      if config.verbose?
        title = "\n#{title}" if @title_level < 2
        title = verbose_prefix + title if config.verbose?
        if (color = @title_colors[@title_level])
        title = title.send(color)
        end
        puts "#{title}"
      elsif title_level < 2
        puts title
      end
    end

    def message(message,  verbose_prefix = '')
      message = verbose_prefix + message if config.verbose?
      puts_indented message if config.verbose?
    end

    def puts(message)
      super(message) unless config.silent?
    end

    def puts_indented(message)
      indented = wrap_string(message, " " * indentation_level)
      puts(indented)
    end

    # adapted from http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
    def wrap_string(txt, indent)
      width = `stty size`.split(' ')[1].to_i - indent.length
      txt.strip.gsub(/(.{1,#{width}})( +|$)\n?|(.{#{width}})/, indent + "\\1\\3\n")
    end

    module Mixin
      def ui_title(title, verbose_prefix = '', relative_indentation = 0)
        UserInterface.instance.title(title)
        UserInterface.instance.indentation_level += relative_indentation
        UserInterface.instance.title_level += 1
        yield if block_given?
        UserInterface.instance.indentation_level -= relative_indentation
        UserInterface.instance.title_level -= 1
      end

      def ui_message(message,  verbose_prefix = '', relative_indentation = 0)
        UserInterface.instance.indentation_level += relative_indentation
        UserInterface.instance.message(message)
        yield if block_given?
        UserInterface.instance.indentation_level -= relative_indentation
      end

      def ui_verbose(message)
        UserInterface.instance.puts(message)
      end

      # def ui_progress_start(count)
      # end

      # def ui_progress_increase(message = nil, ammount = 1)
      # end

      # def ui_progress_complete()
      # end

    end
  end
end
