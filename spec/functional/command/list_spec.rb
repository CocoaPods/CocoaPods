require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::List" do
  extend SpecHelper::TemporaryRepos
  extend SpecHelper::TemporaryDirectory

  def command(arguments = argv)
    command = Pod::Command::List.new(arguments)
  end

  before do
    set_up_test_repo
    config.repos_dir = SpecHelper.tmp_repos_path
  end

  it "presents the known pods" do
    command.run
    Pod::UI.output
    [ /BananaLib/,
      /JSONKit/,
      /\d+ pods were found/
    ].each { |regex| Pod::UI.output.should =~ regex }
  end

  it "returns the new pods" do
    sets = Pod::Source.all_sets
    jsonkit_set = sets.find { |s| s.name == 'JSONKit' }
    dates = {
      'BananaLib' => Time.now,
      'JSONKit'   => Time.parse('01/01/1970') }
    Pod::Specification::Statistics.any_instance.stubs(:creation_dates).returns(dates)
    command(argv('new')).run
    Pod::UI.output.should.include('BananaLib')
    Pod::UI.output.should.not.include('JSONKit')
  end
end


