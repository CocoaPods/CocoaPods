require 'open4'

module Pod
  module Executable
    class Indenter < ::Array
      include Config::Mixin

      attr_accessor :indent
      attr_accessor :io

      def initialize(io = nil)
        @io = io
        @indent = ' ' * UI.indentation_level
      end

      def <<(value)
        super
      ensure
        @io << "#{ indent }#{ value }" if @io
      end
    end


    # TODO
    #
    def self.execute_command(bin, command, raise_on_failure = false)
      bin = `which #{bin}`.strip
      if bin.empty?
        raise Informative, "Unable to locate the executable `#{name}'"
      end
      full_command = "#{bin} #{command}"
      if Config.instance.verbose?
        UI.message("$ #{full_command}")
        stdout, stderr = Indenter.new(STDOUT), Indenter.new(STDERR)
      else
        stdout, stderr = Indenter.new, Indenter.new
      end
      status = Open4.spawn(full_command, :stdout => stdout, :stderr => stderr, :status => true)

      output = stdout.join("\n") + stderr.join("\n") # TODO will this suffice?
      unless status.success?
        if raise_on_failure
          raise Informative, "#{name} #{command}\n\n#{output}"
        else
          UI.message("[!] Failed: #{full_command}".red)
        end
      end
      output
    end


    def executable(name)
      bin = `which #{name}`.strip
      base_method = "base_" << name.to_s
      define_method(base_method) do |command, should_raise|
        if bin.empty?
          raise Informative, "Unable to locate the executable `#{name}'"
        end
        full_command = "#{bin} #{command}"
        if Config.instance.verbose?
          UI.message("$ #{full_command}")
          stdout, stderr = Indenter.new(STDOUT), Indenter.new(STDERR)
        else
          stdout, stderr = Indenter.new, Indenter.new
        end
        status = Open4.spawn(full_command, :stdout => stdout, :stderr => stderr, :status => true)

        output = stdout.join("\n") + stderr.join("\n") # TODO will this suffice?
        unless status.success?
          if should_raise
            raise Informative, "#{name} #{command}\n\n#{output}"
          else
            UI.message("[!] Failed: #{full_command}".red)
          end
        end
        output
      end

      define_method(name) do |command|
        send(base_method, command, false)
      end

      define_method(name.to_s + "!") do |command|
        send(base_method, command, true)
      end

      private name
    end
  end
end
