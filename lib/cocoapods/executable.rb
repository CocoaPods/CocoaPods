module Pod
  # Module which provides support for running executables.
  #
  # In a class it can be used as:
  #
  #     extend Executable
  #     executable :git
  #
  # This will create two methods `git` and `git!` both accept a command but
  # the later will raise on non successful executions. The methods return the
  # output of the command.
  #
  module Executable
    # Creates the methods for the executable with the given name.
    #
    # @param  [Symbol] name
    #         the name of the executable.
    #
    # @return [void]
    #
    def executable(name)
      define_method(name) do |*command|
        Executable.execute_command(name, Array(command).flatten, false, :message => true)
      end

      define_method(name.to_s + '!') do |*command|
        Executable.execute_command(name, Array(command).flatten, true, :message => true)
      end

      define_method(name.to_s + '?') do |*command|
        Executable.execute_command(name, Array(command).flatten, false)
      end
    end

    # Executes the given command displaying it if in verbose mode.
    #
    # @param  [String] bin
    #         The binary to use.
    #
    # @param  [Array<#to_s>] command
    #         The command to send to the binary.
    #
    # @param  [Bool] raise_on_failure
    #         Whether it should raise if the command fails.
    #
    # @raise  If the executable could not be located.
    #
    # @raise  If the command fails and the `raise_on_failure` is set to true.
    #
    # @return [String] the output of the command (STDOUT and STDERR).
    #
    def self.execute_command(executable, command, raise_on_failure = true, message: false, output: :both)
      bin = which(executable)
      raise Informative, "Unable to locate the executable `#{executable}`" if bin.empty?

      command = command.map(&:to_s)
      full_command = "#{bin} #{command.join(' ')}"

      if message && Config.instance.verbose?
        UI.message("$ #{full_command}")
        stdout, stderr = Indenter.new(STDOUT), Indenter.new(STDERR)
      else
        stdout, stderr = Indenter.new, Indenter.new
      end

      status = popen3(bin, command, stdout, stderr)
      stdout, stderr = stdout.join, stderr.join
      unless status.success?
        if raise_on_failure
          raise Informative, "#{full_command}\n\n#{stdout + stderr}"
        elsif message
          UI.message("[!] Failed: #{full_command}".red)
        end
      end

      case output
      when :stdout then stdout
      when :stderr then stderr
      else stdout + stderr
      end
    end

    # Returns the absolute path to the binary with the given name on the current
    # `PATH`, or `nil` if none is found.
    #
    # @param  [String] program
    #         The name of the program being searched for.
    #
    # @return [String,Nil] The absolute path to the given program, or `nil` if
    #                      it wasn't found in the current `PATH`.
    #
    def self.which(program)
      program = program.to_s
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        bin = File.expand_path(program, path)
        if File.file?(bin) && File.executable?(bin)
          return bin
        end
      end
      nil
    end

    private

    def self.popen3(bin, command, stdout, stderr)
      require 'open3'
      Open3.popen3(bin, *command) do |i, o, e, t|
        reader(o, stdout)
        reader(e, stderr)
        i.close

        status = t.value

        o.flush
        e.flush
        sleep(0.01)

        status
      end
    end

    def self.reader(input, output)
      Thread.new do
        buf = ''
        begin
          loop do
            buf << input.readpartial(4096)
            loop do
              string, separator, buf = buf.partition(/[\r\n]/)
              if separator.empty?
                buf = string
                break
              end
              output << (string << separator)
            end
          end
        rescue EOFError
          output << (buf << $/) unless buf.empty?
        end
      end
    end

    #-------------------------------------------------------------------------#

    # Helper class that allows to write to an {IO} instance taking into account
    # the UI indentation level.
    #
    class Indenter < ::Array
      # @return [Fixnum] The indentation level of the UI.
      #
      attr_accessor :indent

      # @return [IO] the {IO} to which the output should be printed.
      #
      attr_accessor :io

      # Init a new Indenter
      #
      # @param [IO] io @see io
      #
      def initialize(io = nil)
        @io = io
        @indent = ' ' * UI.indentation_level
      end

      # Stores a portion of the output and prints it to the {IO} instance.
      #
      # @param  [String] value
      #         the output to print.
      #
      # @return [void]
      #
      def <<(value)
        super
        io << "#{ indent }#{ value }" if io
      end
    end
  end
end
