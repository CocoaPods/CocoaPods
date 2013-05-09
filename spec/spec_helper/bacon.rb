# Encoding: utf-8

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
    when :none
      string
    else
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
      start_time = Time.now.to_f
      error = yield
      elapsed_time = ((Time.now.to_f - start_time) * 1000).round

      if !error.empty?
        puts Bacon.color(:red, "#{spaces}- #{description} [FAILED]")
      elsif disabled
        puts Bacon.color(:yellow, "#{spaces}- #{description} [DISABLED]")
      else
        time_color = elapsed_time > 200 ? :yellow : :none
        puts Bacon.color(:green, "#{spaces}✓ ") + "#{description} " + Bacon.color(time_color, "(#{elapsed_time} ms)")
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

    # Represents the specifications as `:`.
    #
    def handle_specification(name)
      indicator = Bacon.color(nil, ':')
      print indicator
      @indicators||=''
      @indicators << indicator
      yield
    end

    # Represents the requirements as:
    #
    # - [.] successful
    # - [E] error
    # - [F] failure
    # - [_] skipped
    #
    # After the first failure or error all the other requirements are skipped.
    #
    def handle_requirement(description, disabled = false)
      if @first_error
        indicator = Bacon.color(nil, '_')
      else
        error = yield
        if !error.empty?
          @first_error = true
          m = error[0..0]
          c = (m == "E" ? :red : :yellow)
          indicator = Bacon.color(c, m)
        elsif disabled
          indicator =  "D"
        else
          indicator = Bacon.color(nil, '.')
        end
      end
      print indicator
      @indicators||=''
      @indicators << indicator
    end

    def handle_summary
      first_error = ''
      error_count = 0
      ErrorLog.lines.each do |s|
        error_count += 1 if s.include?('Error:') || s.include?('Informative')
        first_error << s if error_count <= 1
      end
      first_error = first_error.gsub(Dir.pwd + '/', '')
      first_error = first_error.gsub(/lib\//, Bacon.color(:yellow, 'lib') + '/')
      first_error = first_error.gsub(/:([0-9]+):/, ':' + Bacon.color(:yellow, '\1') + ':')
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
        line =~ %r{(gems/mocha|spec_helper|ruby_noexec_wrapper)}
      end.join("\n").lstrip << "\n\n")
      super
    end
  end

  #---------------------------------------------------------------------------#

  extend FilterBacktraces

  class Context

    # Add support for disabled specs
    #
    def xit(description, &block)
      Counter[:disabled] += 1
      Bacon.handle_requirement(description, true) {[]}
    end

    # Add support for running only focused specs
    #
    # @note The implementation is a hack because bacon evaluates Context#it
    #       immediately. Therefore this method is intended to be **temporary**.
    #
    # @example
    #
    # module BaconFocusedMode; end
    #
    # describe "A Context" do
    #   it "will *not* runt" do; end
    #   fit "will runt" do; end
    # end
    #
    #
    def fit(description, &block)
      origina_it(description, &block)
    end

    # Add support for focused specs
    #
    alias :origina_it :it
    def it(description, &block)
      unless defined?(::BaconFocusedMode)
        origina_it(description, &block)
      end
    end
  end
end
