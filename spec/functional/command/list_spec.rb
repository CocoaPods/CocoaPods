require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe "Command::List" do
    extend SpecHelper::TemporaryRepos
    extend SpecHelper::TemporaryDirectory

    def command(arguments = argv)
      command = Command::List.new(arguments)
    end

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it "presents the known pods" do
      command.run
      UI.output
      [ /BananaLib/,
        /JSONKit/,
        /\d+ pods were found/
      ].each { |regex| UI.output.should =~ regex }
    end

    it "returns the new pods" do
      sets = Source.all_sets
      jsonkit_set = sets.find { |s| s.name == 'JSONKit' }
      dates = {
        'BananaLib' => Time.now,
        'JSONKit'   => Time.parse('01/01/1970') }
      Specification::Set::Statistics.any_instance.stubs(:creation_dates).returns(dates)
      command(argv('new')).run
      UI.output.should.include('BananaLib')
      UI.output.should.not.include('JSONKit')
    end
  end
end

