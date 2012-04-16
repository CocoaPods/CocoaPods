require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Command" do
  extend SpecHelper::Git
  extend SpecHelper::TemporaryDirectory

  it "creates the local spec-repos directory and creates a clone of the `master' repo" do
    command = Pod::Command.parse('setup', '--silent')
    def command.url; SpecHelper.fixture('spec-repos/master'); end
    command.run
    git_config('master', 'remote.origin.url').should == fixture('spec-repos/master').to_s
  end

  it "preserve push access for the `master' repo" do
    command = Pod::Command.parse('setup', '--silent')
    def command.url; SpecHelper.fixture('spec-repos/master'); end
    command.run
    command2 = Pod::Command.parse('setup', '--silent')
    command2.url.should == 'git://github.com/CocoaPods/Specs.git'
    git('master', 'remote set-url origin git@github.com:CocoaPods/Specs.git')
    command2.url.should == 'git@github.com:CocoaPods/Specs.git'
  end

  it "adds a spec-repo" do
    add_repo('private', fixture('spec-repos/master'))
    git_config('private', 'remote.origin.url').should == fixture('spec-repos/master').to_s
  end

  it "updates a spec-repo" do
    repo1 = add_repo('repo1', fixture('spec-repos/master'))
    git('repo1', 'checkout master') # checkout master, because the fixture is a submodule
    repo2 = add_repo('repo2', repo1.dir)
    make_change(repo1, 'repo1')
    command('repo', 'update', 'repo2')
    (repo2.dir + 'README').read.should.include 'Added!'
  end

  it "updates all the spec-repos" do
    repo1 = add_repo('repo1', fixture('spec-repos/master'))
    git('repo1', 'checkout master') # checkout master, because the fixture is a submodule
    repo2 = add_repo('repo2', repo1.dir)
    repo3 = add_repo('repo3', repo1.dir)
    make_change(repo1, 'repo1')
    command('repo', 'update')
    (repo2.dir + 'README').read.should.include 'Added!'
    (repo3.dir + 'README').read.should.include 'Added!'
  end

  it "creates a new podspec stub file" do
    Dir.chdir(temporary_directory) do
      command('spec', 'create', 'Bananas')
    end
    path = temporary_directory + 'Bananas.podspec'
    spec = Pod::Specification.from_file(path)
    spec.name.should == 'Bananas'
    spec.license.should == { :type => "MIT", :file => "LICENSE" }
    spec.version.should == Pod::Version.new('0.0.1')
    spec.summary.should == 'A short description of Bananas.'
    spec.homepage.should == 'http://EXAMPLE/Bananas'
    spec.authors.should == { `git config --get user.name`.strip => `git config --get user.email`.strip}
    spec.source.should == { :git => 'http://EXAMPLE/Bananas.git', :tag => '0.0.1' }
    spec.description.should == 'An optional longer description of Bananas.'
    spec.source_files[:ios].should == ['Classes', 'Classes/**/*.{h,m}']
  end

  before do
    config.repos_dir = fixture('spec-repos')
  end

  after do
    config.repos_dir = tmp_repos_path
  end

  it "searches for a pod with name matching the given query ignoring case" do
    [
      [' s ', %w{ ASIHTTPRequest ASIWebPageRequest JSONKit SSZipArchive }],
      ['json', %w{ JSONKit SBJson }],
    ].each do |query, results|
      command = Pod::Command.parse('search', '--silent', query)
      def command.puts(msg = '')
        (@printed ||= '') << "#{msg}\n"
      end
      command.run
      printed = command.instance_variable_get(:@printed)
      results.each { |pod| printed.should.include? pod }
    end
  end

  it "searches for a pod with name, summary, or description matching the given query ignoring case" do
    [
      ['dROP', %w{ Reachability }],
      ['is', %w{ ASIHTTPRequest SSZipArchive }],
    ].each do |query, results|
      command = Pod::Command.parse('search', '--silent', '--full', query)
      def command.puts(msg = '')
        (@printed ||= '') << "#{msg}\n"
      end
      command.run
      printed = command.instance_variable_get(:@printed)
      results.each { |pod| printed.should.include? pod }
    end
  end
end
