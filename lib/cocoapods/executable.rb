require 'open4'

module Pod
  module Executable
    class Indenter < ::Array
      attr_accessor :indent
      attr_accessor :io

      def initialize(io = nil, indent = '   ')
        @io = io
        @indent = indent
      end

      def <<(value)
        super
      ensure
        @io << "#{ indent }#{ value }" if @io
      end
    end

    def executable(name)
      bin = `which #{name}`.strip
      define_method(name) do |command|
        if bin.empty?
          raise Informative, "Unable to locate the executable `#{name}'"
        end
        full_command = "#{bin} #{command}"
        if Config.instance.verbose?
          puts "   $ #{full_command}"
          stdout, stderr = Indenter.new(STDOUT), Indenter.new(STDERR)
        else
          stdout, stderr = Indenter.new, Indenter.new
        end
        status = Open4.spawn(full_command, :stdout => stdout, :stderr => stderr, :status => true)
        # TODO not sure that we should be silent in case of a failure.
        puts (Config.instance.verbose? ? '   ' : '') << "[!] Failed: #{full_command}".red unless status.success? || Config.instance.silent?
        stdout.join("\n") + stderr.join("\n") # TODO will this suffice?
      end
      private name
    end
  end
end
