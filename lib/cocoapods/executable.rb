module Pod
  module Executable
    def executable(name)
      bin = `which #{name}`.strip
      define_method(name) do |command|
        if bin.empty?
          raise Informative, "Unable to locate the executable `#{name}'"
        end
        if Config.instance.verbose?
          puts "-> #{bin} #{command}"
          `#{bin} #{command} 1>&2`
        else
          `#{bin} #{command} 2> /dev/null`
        end
      end
      private name
    end
  end
end
