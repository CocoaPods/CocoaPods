require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::Search" do
  extend SpecHelper::Command
  extend SpecHelper::TemporaryDirectory
  extend SpecHelper::TemporaryRepos

  before do
    config.repos_dir = fixture('spec-repos')
  end

  it "runs with correct parameters" do
    lambda { run_command('search', 'table') }.should.not.raise
    lambda { run_command('search', 'table', '--full') }.should.not.raise
  end

  it "complains for wrong parameters" do
    lambda { run_command('search') }.should.raise Pod::Command::Help
    lambda { run_command('search', 'too', 'many') }.should.raise Pod::Command::Help
    lambda { run_command('search', 'too', '--wrong') }.should.raise Pod::Command::Help
    lambda { run_command('search', '--wrong') }.should.raise Pod::Command::Help
  end

  it "presents the search results" do
    output = run_command('search', 'table')
    output.should.include 'EGOTableViewPullRefresh'
  end

  it "searches for a pod with name matching the given query ignoring case" do
    [
      [' s ', %w{ ASIHTTPRequest ASIWebPageRequest JSONKit SSZipArchive }],
      ['json', %w{ JSONKit SBJson }],
    ].each do |query, results|
      output = run_command('search', query)
      results.each { |pod| output.should.include? pod }
    end
  end

  it "searches for a pod with name, summary, or description matching the given query ignoring case" do
    [
      ['dROP', %w{ Reachability }],
      ['is', %w{ ASIHTTPRequest SSZipArchive }],
      ['luke redpath', %w{ Kiwi libPusher LRMocky LRResty LRTableModel}],
    ].each do |query, results|
      output = run_command('search', '--full', query)
      results.each { |pod| output.should.include? pod }
    end
  end
end



