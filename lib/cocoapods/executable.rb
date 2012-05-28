module Pod
  module Executable
    def executable(name)
      bin = `which #{name}`.strip
      define_method(name) do |command|
        if bin.empty?
          raise Informative, "Unable to locate the executable `#{name}'"
        end
        full_command = "#{bin} #{command}"
        if Config.instance.verbose?
          puts "$ #{full_command}"
          output = `#{full_command} 2>&1 | /usr/bin/tee /dev/tty`
        else
          output = `#{full_command} 2>&1`
        end
        # TODO not sure that we should be silent in case of a failure.
        puts "[!] Failed: #{full_command}".red unless Config.instance.silent? || $?.exitstatus.zero?
        output
      end
      private name
    end
  end
end
