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
        Executable.execute_command(name, Array(command).flatten, false)
      end

      define_method(name.to_s + '!') do |*command|
        Executable.execute_command(name, Array(command).flatten, true)
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
    # @todo   Find a way to display the live output of the commands.
    #
    def self.execute_command(executable, command, raise_on_failure)
      bin = `which #{executable}`.strip
      raise Informative, "Unable to locate the executable `#{executable}`" if bin.empty?

      require 'shellwords'

      command = command.map(&:to_s)
      full_command = "#{bin} #{command.join(' ')}"
      
      UI.message("$ #{full_command}") if Config.instance.verbose?
      
      output = StringIO.new
      status = with_verbose do
        spawn(bin, command, Indenter.new(output))
      end
      
      unless status.success?
        if raise_on_failure
          raise Informative, "#{full_command}\n\n#{output.string}"
        else
          UI.message("[!] Failed: #{full_command}".red)
        end
      end
      
      output.string
    end

    private
    
    def self.spawn bin, command, output
      require 'pty'
      PTY.spawn(bin, *command) do |r, _, pid|
        begin
          r.each { |line| output.write line }
          status = PTY.check(pid)
          return status if status
        end  
      end
    end
    
    # Yields to a block, redirecting STDOUT/STDERR if verbose output is used. 
    #
    def self.with_verbose &block
      if Config.instance.verbose?
        with_redirected(Indenter.new(STDOUT), Indenter.new(STDERR), &block)
      else
        block.call
      end
    end
    
    # Redirects the output to the given stdout/stderr.
    #
    def self.with_redirected stdout, stderr
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = stdout if stdout
      $stderr = stderr if stderr
      yield
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end

    #-------------------------------------------------------------------------#

    # Helper class that allows to write to a {IO} instance taking into account
    # the UI indentation level.
    #
    class Indenter
      # @return [Fixnum] The indentation level of the UI.
      #
      attr_accessor :indent

      # @return [IO] the {IO} to which the output should be printed.
      #
      attr_accessor :io

      # @param [IO] io @see io
      #
      def initialize(io)
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
      def write(value)
        @io.write "#{ indent }#{ value }"
      end
      
      def string
        @io.string
      end
      
      def flush
        # We ignore calls to flush.
      end
    end
  end
end
