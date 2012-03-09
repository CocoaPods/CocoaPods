# Graciously yanked from https://github.com/zen-cms/Zen-Core
# MIT License
# Thanks, YorickPeterse!

#:nodoc:
module Bacon
  #:nodoc:
  module ColorOutput
    #:nodoc:
    def handle_specification(name)
      puts spaces + name
      yield
      puts if Counter[:context_depth] == 1
    end

    #:nodoc:
    def handle_requirement(description)
      error = yield

      if !error.empty?
        puts "#{spaces} \e[31m- #{description} [FAILED]\e[0m"
      else
        puts "#{spaces} \e[32m- #{description}\e[0m"
      end
    end

    #:nodoc:
    def handle_summary
      print ErrorLog  if Backtraces
      puts "%d specifications (%d requirements), %d failures, %d errors" %
        Counter.values_at(:specifications, :requirements, :failed, :errors)
    end

    #:nodoc:
    def spaces
      if Counter[:context_depth] == 0
        Counter[:context_depth] = 1
      end

      return ' ' * (Counter[:context_depth] - 1)
    end
  end # ColorOutput
end # Bacon
