module Pod
  module Executable
    def executable(name)
      bin = `which #{name}`.strip
      define_method(name) do |command|
        if bin.empty?
          raise Informative, "Unable to locate the executable `#{name}'"
        end
        if Config.instance.verbose?
          print "   $ #{name} #{command.length > 20 ? command[0..20] + '...' : command}\r"
          $stdout.flush

          output = `#{bin} #{command} 2>&1`

          puts "   #{$?.exitstatus.zero? ? '-' : '!'.red} #{name} #{command}"
          output = output.gsub(/^ */,'     ')
          puts output unless output.strip.empty?
        else
          `#{bin} #{command} 2> /dev/null`
        end
      end
      private name
    end
  end
end
