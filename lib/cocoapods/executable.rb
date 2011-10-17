module Pod
  module Executable
    def executable(name)
      define_method(name) do |command|
        if Config.instance.verbose?
          puts "#{name} #{command}"
          `#{name} #{command} 1>&2`
        else
          `#{name} #{command} 2> /dev/null`
        end
      end
      private name
    end
  end
end
