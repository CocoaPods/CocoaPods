module Pod
  module Executable
    def executable(name)
      define_method(name) do |command|
        if Config.instance.verbose?
          `#{name} #{command} 1>&2`
        else
          `#{name} #{command} 2> /dev/null`
        end
      end
    end
  end
end
