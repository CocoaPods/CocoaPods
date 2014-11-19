require 'cocoapods/user_interface/error_report'

module Pod
  # Provides support for UI output. It provides support for nested sections of
  # information and for a verbose mode.
  #
  module UserInterface
    require 'colored'

    @title_colors      =  %w(    yellow green    )
    @title_level       =  0
    @indentation_level =  2
    @treat_titles_as_messages = false
    @warnings = []

    class << self
      include Config::Mixin

      attr_accessor :indentation_level
      attr_accessor :title_level
      attr_accessor :warnings

      # @return [Bool] Whether the wrapping of the strings to the width of the
      #         terminal should be disabled.
      #
      attr_accessor :disable_wrap
      alias_method :disable_wrap?, :disable_wrap

      # Prints a title taking an optional verbose prefix and
      # a relative indentation valid for the UI action in the passed
      # block.
      #
      # In verbose mode titles are printed with a color according
      # to their level. In normal mode titles are printed only if
      # they have nesting level smaller than 2.
      #
      # @todo Refactor to title (for always visible titles like search)
      #       and sections (titles that represent collapsible sections).
      #
      def section(title, verbose_prefix = '', relative_indentation = 0)
        if config.verbose?
          title(title, verbose_prefix, relative_indentation)
        elsif title_level < 1
          puts title
        end

        self.indentation_level += relative_indentation
        self.title_level += 1
        yield if block_given?
        self.indentation_level -= relative_indentation
        self.title_level -= 1
      end

      # In verbose mode it shows the sections and the contents.
      # In normal mode it just prints the title.
      #
      # @return [void]
      #
      def titled_section(title, options = {})
        relative_indentation = options[:relative_indentation] || 0
        verbose_prefix = options[:verbose_prefix] || ''
        if config.verbose?
          title(title, verbose_prefix, relative_indentation)
        else
          puts title
        end

        self.indentation_level += relative_indentation
        self.title_level += 1
        yield if block_given?
        self.indentation_level -= relative_indentation
        self.title_level -= 1
      end

      # A title opposed to a section is always visible
      #
      def title(title, verbose_prefix = '', relative_indentation = 2)
        if @treat_titles_as_messages
          message(title, verbose_prefix)
        else
          title = verbose_prefix + title if config.verbose?
          title = "\n#{title}" if @title_level < 2
          if (color = @title_colors[@title_level])
            title = title.send(color)
          end
          puts "#{title}"
        end

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
      # @todo Clean interface.
      #
      def message(message, verbose_prefix = '', relative_indentation = 2)
        message = verbose_prefix + message if config.verbose?
        puts_indented message if config.verbose?

        self.indentation_level += relative_indentation
        yield if block_given?
        self.indentation_level -= relative_indentation
      end

      # Prints an info to the user. The info is always displayed.
      # It respects the current indentation level only in verbose
      # mode.
      #
      # Any title printed in the optional block is treated as a message.
      #
      def info(message)
        indentation = config.verbose? ? self.indentation_level : 0
        indented = wrap_string(message, indentation)
        puts(indented)

        self.indentation_level += 2
        @treat_titles_as_messages = true
        yield if block_given?
        @treat_titles_as_messages = false
        self.indentation_level -= 2
      end

      # Prints an important message to the user.
      #
      # @param [String] message The message to print.
      #
      # return [void]
      #
      def notice(message)
        puts("\n[!] #{message}".green)
      end

      # Returns a string containing relative location of a path from the Podfile.
      # The returned path is quoted. If the argument is nil it returns the
      # empty string.
      #
      def path(pathname)
        if pathname
          from_path = config.podfile_path.dirname if config.podfile_path
          from_path ||= Pathname.pwd
          path = Pathname(pathname).relative_path_from(from_path)
          "`#{path}`"
        else
          ''
        end
      end

      # Prints the textual representation of a given set.
      #
      def pod(set, mode = :normal, statistics_provider = nil)
        if mode == :name_and_version
          puts_indented "#{set.name} #{set.versions.first.version}"
        else
          pod = Specification::Set::Presenter.new(set, statistics_provider)
          title = "\n-> #{pod.name} (#{pod.version})"
          if pod.spec.deprecated?
            title += " #{pod.deprecation_description}"
            colored_title = title.red
          else
            colored_title = title.green
          end

          title(colored_title, '', 1) do
            puts_indented pod.summary if pod.summary
            puts_indented "pod '#{pod.name}', '~> #{pod.version}'"
            labeled('Homepage', pod.homepage)
            labeled('Source',   pod.source_url)
            labeled('Versions', pod.verions_by_source)
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
      def labeled(label, value, justification = 12)
        if value
          title = "- #{label}:".ljust(justification)
          output = begin
            if value.is_a?(Array)
              lines = [wrap_string(title, self.indentation_level)]
              value.each do |v|
                lines << wrap_string("- #{v}", self.indentation_level + 2)
              end
              lines.join("\n")
            else
              wrap_string(title + "#{value}", self.indentation_level)
            end + "\n"
          end
          puts output
          output
        end
      end

      # Prints a message respecting the current indentation level and
      # wrapping it to the terminal width if necessary.
      #
      def puts_indented(message = '')
        indented = wrap_string(message, self.indentation_level)
        puts(indented)
      end

      # Prints the stored warnings. This method is intended to be called at the
      # end of the execution of the binary.
      #
      # @return [void]
      #
      def print_warnings
        STDOUT.flush
        warnings.each do |warning|
          next if warning[:verbose_only] && !config.verbose?
          STDERR.puts("\n[!] #{warning[:message]}".yellow)
          warning[:actions].each do |action|
            string = "- #{action}"
            string = wrap_string(string, 4)
            puts(string)
          end
        end
      end

      public

      # @!group Basic methods
      #-----------------------------------------------------------------------#

      # prints a message followed by a new line unless config is silent.
      #
      def puts(message = '')
        STDOUT.puts(message) unless config.silent?
      end

      # prints a message followed by a new line unless config is silent.
      #
      def print(message)
        STDOUT.print(message) unless config.silent?
      end

      # gets input from $stdin
      #
      def gets
        $stdin.gets
      end

      # Stores important warning to the user optionally followed by actions
      # that the user should take. To print them use {#print_warnings}.
      #
      # @param [String]  message The message to print.
      # @param [Array]   actions The actions that the user should take.
      #
      # return [void]
      #
      def warn(message, actions = [], verbose_only = false)
        warnings << { :message => message, :actions => actions, :verbose_only => verbose_only }
      end

      private

      # @!group Helpers
      #-----------------------------------------------------------------------#

      # @return [String] Wraps a string taking into account the width of the
      # terminal and an option indent. Adapted from
      # http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
      #
      # @param [String] txt     The string to wrap
      #
      # @param [String] indent  The string to use to indent the result.
      #
      # @return [String]        The formatted string.
      #
      # @note If CocoaPods is not being run in a terminal or the width of the
      # terminal is too small a width of 80 is assumed.
      #
      def wrap_string(string, indent = 0)
        if disable_wrap
          string
        else
          first_space = ' ' * indent
          indented = CLAide::Helper.wrap_with_indent(string, indent, 9999)
          first_space + indented
        end
      end
    end
  end
  UI = UserInterface

  #---------------------------------------------------------------------------#

  # Redirects cocoapods-core UI.
  #
  module CoreUI
    class << self
      def puts(message)
        UI.puts message
      end

      def warn(message)
        UI.warn message
      end
    end
  end
end

#---------------------------------------------------------------------------#

module Xcodeproj
  # Redirects xcodeproj UI.
  #
  module UserInterface
    def self.puts(message)
      ::Pod::UI.puts message
    end

    def self.warn(message)
      ::Pod::UI.warn message
    end
  end
end
