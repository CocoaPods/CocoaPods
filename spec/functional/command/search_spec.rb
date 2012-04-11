require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::Search" do
  extend SpecHelper::Git

  before do
    config.repos_dir = fixture('spec-repos')
  end

  after do
    config.repos_dir = tmp_repos_path
  end

  def command(arguments = argv)
    command = Pod::Command::Search.new(arguments)
  end

  it "runs with correct parameters" do
    lambda { command(argv('table')).run }.should.not.raise
    lambda { command(argv('table','--full')).run }.should.not.raise
  end

  it "complains for wrong parameters" do
    lambda { command(argv('too','many')).run }.should.raise Pod::Command::Help
    lambda { command(argv('too','--wrong')).run }.should.raise Pod::Command::Help
    lambda { command(argv('--missing_query')).run }.should.raise Pod::Command::Help
  end

  it "presents the search results" do
  search = command(argv('table'))
    search.run
    output = search.output
    output.should.include 'EGOTableViewPullRefresh'
  end
end



