require File.expand_path('../spec_helper', __FILE__)

module Pod
  describe DSLError do
    before do
      @dsl_path = fixture('standard_error_podspec/Three20.podspec')
      backtrace = [
        "#{@dsl_path}:2:in `error line'",
        "#{@dsl_path}:127:in `block (2 levels) in _eval_podspec'",
        "lib/cocoapods-core/specification.rb:41:in `initialize'",
      ]
      exception = stub(:backtrace => backtrace)
      description = 'Invalid podspec'
      @err = DSLError.new(description, @dsl_path, exception)

      lines = ["first line\n", "error line\n", "last line\n"]
      File.stubs(:read).returns(lines.join(''))
    end

    it 'returns a properly formed message' do
      @err.message.should == <<-MSG.strip_heredoc

        [!] Invalid podspec.

         #  from #{@dsl_path.expand_path}:2
         #  -------------------------------------------
         #  first line
         >  error line
         #  last line
         #  -------------------------------------------
      MSG
    end

    it 'parses syntax error messages for well-formed messages' do
      code = "puts 'hi'\nputs())\nputs 'bye'"
      # rubocop:disable Eval
      syntax_error = should.raise(SyntaxError) { eval(code, nil, @dsl_path.to_s) }
      # rubocop:enable Eval
      @err.stubs(:description).returns("Invalid `Three20.podspec` file: #{syntax_error.message}")
      @err.stubs(:underlying_exception).returns(syntax_error)
      File.stubs(:read).returns(code)
      @err.message.should == <<-MSG.strip_heredoc

        [!] Invalid `Three20.podspec` file: syntax error, unexpected ')', expecting end-of-input.

         #  from #{@dsl_path.expand_path}:2
         #  -------------------------------------------
         #  puts 'hi'
         >  puts())
         #  puts 'bye'
         #  -------------------------------------------
      MSG
    end

    it 'uses the passed-in contents' do
      @err.stubs(:contents).returns("puts 'hi'\nputs 'there'\nputs 'bye'")
      File.expects(:exist?).never
      @err.message.should == <<-MSG.strip_heredoc

        [!] Invalid podspec.

         #  from #{@dsl_path}:2
         #  -------------------------------------------
         #  puts 'hi'
         >  puts 'there'
         #  puts 'bye'
         #  -------------------------------------------
      MSG
    end

    it 'includes the given description in the message' do
      @err.message.should.include?('Invalid podspec.')
    end

    it 'includes the path of the dsl file in the message' do
      @err.message.should.include?("from #{@dsl_path}")
    end

    it 'includes in the message the contents of the line that raised the exception' do
      @err.message.should.include?('error line')
    end

    it 'is robust against a nil backtrace' do
      @err.underlying_exception.stubs(:backtrace => nil)
      lambda { @err.message }.should.not.raise
    end

    it 'is robust against a backtrace non including the path of the dsl file' do
      @err.underlying_exception.stubs(:backtrace).returns [
        "lib/cocoapods-core/specification.rb:41:in `initialize'",
      ]
      lambda { @err.message }.should.not.raise
    end

    it "is robust against a backtrace that doesn't include the line number of the dsl file that originated the error" do
      @err.underlying_exception.stubs(:backtrace).returns [@dsl_path.to_s]
      lambda { @err.message }.should.not.raise
    end

    it 'is against a nil path of the dsl file' do
      @err.stubs(:dsl_path => nil)
      lambda { @err.message }.should.not.raise
    end

    it 'is robust against non existing paths' do
      @err.stubs(:dsl_path => 'find_me_baby')
      lambda { @err.message }.should.not.raise
    end

    it 'can handle the first line of the dsl file' do
      @err.underlying_exception.stubs(:backtrace).returns ["#{@dsl_path}:1"]
      lambda { @err.message }.should.not.raise
      @err.message.should.include?('first line')
      @err.message.should.not.include?('last line')
    end

    it 'can handle the last line of the dsl file' do
      @err.underlying_exception.stubs(:backtrace).returns ["#{@dsl_path}:3"]
      lambda { @err.message }.should.not.raise
      @err.message.should.not.include?('first line')
      @err.message.should.include?('last line')
    end
  end
end
