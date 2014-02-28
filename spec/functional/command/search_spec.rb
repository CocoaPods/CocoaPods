require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Search do

    extend SpecHelper::TemporaryRepos

    before do
      @test_source = Source.new(fixture('spec-repos/test_repo'))
      Source::Aggregate.any_instance.stubs(:all).returns([@test_source])
      SourcesManager.updated_search_index = nil
    end

    it "runs with correct parameters" do
      lambda { run_command('search', 'JSON') }.should.not.raise
      lambda { run_command('search', 'JSON', '--full') }.should.not.raise
    end

    it "complains for wrong parameters" do
      lambda { run_command('search') }.should.raise CLAide::Help
      lambda { run_command('search', 'too', '--wrong') }.should.raise CLAide::Help
      lambda { run_command('search', '--wrong') }.should.raise CLAide::Help
    end

    it "searches for a pod with name matching the given query ignoring case" do
      output = run_command('search', 'json')
      output.should.include? 'JSONKit'
    end

    it "searches for a pod with name, summary, or description matching the given query ignoring case" do
      output = run_command('search', 'Engelhart', '--full')
      output.should.include? 'JSONKit'
    end

    it "restricts the search to Pods supported on iOS" do
      output = run_command('search', 'BananaLib', '--ios')
      output.should.include? 'BananaLib'
      Specification.any_instance.stubs(:available_platforms).returns([Platform.osx])
      output = run_command('search', 'BananaLib', '--ios')
      output.should.not.include? 'BananaLib'
    end

    it "restricts the search to Pods supported on iOS" do
      output = run_command('search', 'BananaLib', '--osx')
      output.should.not.include? 'BananaLib'
    end

    it "outputs with the silent parameter" do
      output = run_command('search', 'BananaLib', '--silent')
      output.should.include? 'BananaLib'
    end

    it "shows a friendly message when searching with invalid regex" do
      lambda { run_command('search', '+') }.should.raise CLAide::Help
    end

    describe "option --web" do

      extend SpecHelper::TemporaryRepos

      it "searches the web via the open! command" do
        Command::Search.any_instance.expects(:open!).with('http://cocoapods.org/?q=bananalib')
        run_command('search', '--web', 'bananalib')
      end

      it "includes option --osx correctly" do
        Command::Search.any_instance.expects(:open!).with('http://cocoapods.org/?q=on%3Aosx%20bananalib')
        run_command('search', '--web', '--osx', 'bananalib')
      end

      it "includes option --ios correctly" do
        Command::Search.any_instance.expects(:open!).with('http://cocoapods.org/?q=on%3Aios%20bananalib')
        run_command('search', '--web', '--ios', 'bananalib')
      end

      it "does not matter in which order the ios/osx options are set" do
        Command::Search.any_instance.expects(:open!).with('http://cocoapods.org/?q=on%3Aosx%20on%3Aios%20bananalib')
        run_command('search', '--web', '--ios', '--osx', 'bananalib')

        Command::Search.any_instance.expects(:open!).with('http://cocoapods.org/?q=on%3Aosx%20on%3Aios%20bananalib')
        run_command('search', '--web', '--osx', '--ios', 'bananalib')
      end

    end

  end
end
