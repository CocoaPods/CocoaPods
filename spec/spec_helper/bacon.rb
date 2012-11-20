module Bacon
  summary_at_exit

  @needs_first_put = true

  def self.color(color, string)
    case color
    when :red
      "\e[31m#{string}\e[0m"
    when :green
      "\e[32m#{string}\e[0m"
    when :yellow
      "\e[33m#{string}\e[0m"
    else
      # Support for Conque
      "\e[0m#{string}\e[0m"
    end
  end

  #---------------------------------------------------------------------------#

  # Overrides the SpecDoxzRtput to provide colored output by default
  #
  # Based on https://github.com/zen-cms/Zen-Core and subsequently modified
  # which is available under the MIT License. Thanks YorickPeterse!
  #
  module SpecDoxOutput

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
        puts Bacon.color(:red, "#{spaces}- #{description} [FAILED]")
      elsif disabled
        puts Bacon.color(:yellow, "#{spaces}- #{description} [DISABLED]")
      else
        puts Bacon.color(:green, "#{spaces}- #{description}")
      end
    end

    #:nodoc:
    def handle_summary
      print ErrorLog  if Backtraces
      unless Counter[:disabled].zero?
        puts Bacon.color(:yellow, "#{Counter[:disabled]} disabled specifications\n")
      end
      puts "%d specifications (%d requirements), %d failures, %d errors" %
        Counter.values_at(:specifications, :requirements, :failed, :errors)
    end

    #:nodoc:
    def spaces
      return '  ' * @specs_depth
    end
  end

  #---------------------------------------------------------------------------#

  # Overrides the TestUnitOutput to provide colored result output.
  #
  module TestUnitOutput
    def handle_requirement(description, disabled = false)
      error = yield
      if !error.empty?
        m = error[0..0]
        c = (m == "E" ? :red : :yellow) unless @first_error
        print Bacon.color(c, m)
        @first_error = true
      elsif disabled
        print "D"
      else
        print Bacon.color(nil, '.')
      end
    end

    def handle_summary
      first_error = ''
      error_count = 0
      ErrorLog.lines.each do |s|
        error_count += 1 if s.include?('Error:')
        first_error << s if error_count <= 1
      end
      puts "\n#{first_error}" if Backtraces
      unless Counter[:disabled].zero?
        puts Bacon.color(:yellow, "#{Counter[:disabled]} disabled specifications")
      end
      result = "%d specifications (%d requirements), %d failures, %d errors" %
        Counter.values_at(:specifications, :requirements, :failed, :errors)
      if Counter[:failed].zero?
        puts Bacon.color(:green, result)
      else
        puts Bacon.color(:red, result)
      end
    end
  end

  #---------------------------------------------------------------------------#

  module FilterBacktraces
    def handle_summary
      ErrorLog.replace(ErrorLog.split("\n").reject do |line|
        line =~ %r{(gems/mocha|spec_helper)}
      end.join("\n").lstrip << "\n\n")
      super
    end
  end

  #---------------------------------------------------------------------------#

  extend FilterBacktraces

  class Context
    def xit(description, *args)
      Counter[:disabled] += 1
      Bacon.handle_requirement(description, true) {[]}
    end
  end
end



