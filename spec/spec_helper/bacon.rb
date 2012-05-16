module Bacon
  summary_at_exit

  @needs_first_put = true

  module ColorOutput
    # Graciously yanked from https://github.com/zen-cms/Zen-Core and subsequently modified
    # MIT License
    # Thanks, YorickPeterse!    #:nodoc:
    def handle_specification(name)
      if @needs_first_put
        @needs_first_put = false
        puts
      end
      @specs_depth = @specs_depth || 0
      puts spaces + name
      @specs_depth += 1

      yield

      @specs_depth -= 1
      puts if @specs_depth.zero?
    end

    #:nodoc:
    def handle_requirement(description, disabled = false)
      error = yield

      if !error.empty?
        puts "#{spaces}\e[31m- #{description} [FAILED]\e[0m"
      elsif disabled
        puts "#{spaces}\e[33m- #{description} [DISABLED]\e[0m"
      else
        puts "#{spaces}\e[32m- #{description}\e[0m"
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
      return '  ' * @specs_depth
    end
  end
  extend ColorOutput

  module FilterBacktraces
    def handle_summary
      ErrorLog.replace(ErrorLog.split("\n").reject do |line|
        line =~ %r{(gems/mocha|spec_helper)}
      end.join("\n").lstrip << "\n\n")
      super
    end
  end
  extend FilterBacktraces

  class Context
    def xit(description, *args)
      Bacon.handle_requirement(description, true) {[]}
      title = "\e[33m-> Disabled Specificiations\e[0m"
      ErrorLog.insert(0,"#{title}\n") unless ErrorLog.include?(title)
      ErrorLog.insert(title.length, "\n - #{self.name} #{description}")
    end
  end
end
