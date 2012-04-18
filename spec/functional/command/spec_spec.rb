require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::Spec" do
  extend SpecHelper::Command
  extend SpecHelper::Github
  extend SpecHelper::TemporaryDirectory

  it "runs with correct parameters" do
    lambda{ run_command('spec', 'create', 'Bananas') }.should.not.raise
    expect_github_repo_request
    expect_github_user_request
    expect_github_tags_request
    lambda{ run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git') }.should.not.raise
  end

  it "complains for wrong parameters" do
    lambda { run_command('spec', '--create') }.should.raise Pod::Command::Help
    lambda { run_command('spec', 'createa') }.should.raise Pod::Command::Help
    lambda { run_command('spec', 'create') }.should.raise Pod::Command::Help
  end

  it "creates a new podspec stub file" do
    run_command('spec', 'create', 'Bananas')
    path = temporary_directory + 'Bananas.podspec'
    spec = Pod::Specification.from_file(path)
    spec.name.should               == 'Bananas'
    spec.license.should            == { :type => "MIT", :file => "LICENSE" }
    spec.version.should            == Pod::Version.new('0.0.1')
    spec.summary.should            == 'A short description of Bananas.'
    spec.homepage.should           == 'http://EXAMPLE/Bananas'
    spec.authors.should            == { `git config --get user.name`.strip => `git config --get user.email`.strip}
    spec.source.should             == { :git => 'http://EXAMPLE/Bananas.git', :tag => '0.0.1' }
    spec.description.should        == 'An optional longer description of Bananas.'
    spec.source_files[:ios].should == ['Classes', 'Classes/**/*.{h,m}']
  end

  it "correctly creates a podspec from github" do
    expect_github_repo_request
    expect_github_user_request
    expect_github_tags_request
    run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
    path = temporary_directory + 'libPusher.podspec'
    spec = Pod::Specification.from_file(path)
    spec.name.should     == 'libPusher'
    spec.license.should  == { :type => "MIT", :file => "LICENSE" }
    spec.version.should  == Pod::Version.new('1.3')
    spec.summary.should  == 'An Objective-C interface to Pusher (pusherapp.com)'
    spec.homepage.should == 'https://github.com/lukeredpath/libPusher'
    spec.authors.should  == {"Luke Redpath"=>"luke@lukeredpath.co.uk"}
    spec.source.should   == { :git => 'https://github.com/lukeredpath/libPusher.git', :tag => 'v1.3' }
  end

  it "correctly suggests the head commit if a suitable tag is not available on github" do
    expect_github_repo_request
    expect_github_user_request
    expect_github_tags_request([{"name" => "experiment"}])
    expect_github_branches_request
    run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
    path = temporary_directory + 'libPusher.podspec'
    spec = Pod::Specification.from_file(path)
    spec.version.should == Pod::Version.new('0.0.1')
    spec.source.should  == { :git => 'https://github.com/lukeredpath/libPusher.git', :commit => '5f482b0693ac2ac1ad85d1aabc27ec7547cc0bc7' }
  end

  it "provides a markdown template if a github repo doesn't have semantic version tags" do
    expect_github_repo_request
    expect_github_user_request
    expect_github_tags_request([{"name" => "experiment"}])
    expect_github_branches_request
    output = run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
    output.should.include 'MARKDOWN TEMPLATE'
    output.should.include 'Please add semantic version tags'
  end

end



