require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Command" do
  extend SpecHelper::Git
  extend SpecHelper::TemporaryDirectory

  before do
    fixture('spec-repos/master') # ensure the archive is unpacked
  end

  it "creates the local spec-repos directory and creates a clone of the `master' repo" do
    command = Pod::Command.parse('setup', '--silent')
    def command.master_repo_url; SpecHelper.fixture('spec-repos/master'); end
    command.run
    git_config('master', 'remote.origin.url').should == fixture('spec-repos/master').to_s
  end

  it "adds a spec-repo" do
    add_repo('private', fixture('spec-repos/master'))
    git_config('private', 'remote.origin.url').should == fixture('spec-repos/master').to_s
  end

  it "updates a spec-repo" do
    repo1 = add_repo('repo1', fixture('spec-repos/master'))
    repo2 = add_repo('repo2', repo1.dir)
    make_change(repo1, 'repo1')
    command('repo', 'update', 'repo2')
    (repo2.dir + 'README').read.should.include 'Added!'
  end

  it "updates all the spec-repos" do
    repo1 = add_repo('repo1', fixture('spec-repos/master'))
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
    spec = Pod::Specification.from_podspec(path)
    spec.read(:name).should == 'Bananas'
    spec.read(:version).should == Pod::Version.new('1.0.0')
    spec.read(:summary).should == 'A short description of Bananas.'
    spec.read(:homepage).should == 'http://example.com/Bananas'
    spec.read(:authors).should == { `git config --get user.name`.strip => `git config --get user.email`.strip }
    spec.read(:source).should == { :git => 'http://example.com/Bananas.git', :tag => '1.0.0' }
    spec.read(:description).should == 'An optional longer description of Bananas.'
    spec.read(:source_files).should == [Pathname.new('Classes'), Pathname.new('Classes/**/*.{h,m}')]
    spec.read(:xcconfig).should == { 'OTHER_LDFLAGS' => '-framework SomeRequiredFramework' }
  end

  before do
    config.repos_dir = fixture('spec-repos')
  end

  after do
    config.repos_dir = tmp_repos_path
  end

  it "searches for a pod who's name matches the given query ignoring case" do
    [
      [
        ' s ',
        "==> ASIHTTPRequest (1.8, 1.8.1)\n" \
        "    Easy to use CFNetwork wrapper for HTTP requests, Objective-C, " \
        "Mac OS X and iPhone\n\n" \
        "==> ASIWebPageRequest (1.8, 1.8.1)\n" \
        "    The ASIWebPageRequest class included with ASIHTTPRequest lets you " \
        "download\n    complete webpages, including external resources like " \
        "images and stylesheets.\n\n" \
        "==> JSONKit (1.4)\n" \
        "    A Very High Performance Objective-C JSON Library.\n\n" \
        "==> SSZipArchive (1.0)\n" \
        "    Utility class for unzipping files on iOS and Mac.\n\n"
      ],
      [
        'json',
        "==> JSONKit (1.4)\n" \
        "    A Very High Performance Objective-C JSON Library.\n\n",
      ]
    ].each do |query, result|
      command = Pod::Command.parse('search', '--silent', query)
      def command.puts(msg = '')
        (@printed ||= '') << "#{msg}\n"
      end
      command.run
      printed = command.instance_variable_get(:@printed)
      printed.should == result
    end
  end

  it "searches for a pod who's name, summary, or description matches the given query ignoring case" do
    [
      [
        'systemCONfiguration',
        "==> Reachability (2.0.4)\n" \
        "    A wrapper for the SystemConfiguration Reachablity APIs.\n\n",
      ],
      [
        'is',
        "==> ASIHTTPRequest (1.8, 1.8.1)\n" \
        "    Easy to use CFNetwork wrapper for HTTP requests, Objective-C, " \
        "Mac OS X and iPhone\n\n" \
        "==> Reachability (2.0.4)\n" \
        "    A wrapper for the SystemConfiguration Reachablity APIs.\n\n" \
        "==> SSZipArchive (1.0)\n" \
        "    Utility class for unzipping files on iOS and Mac.\n\n"
      ]
    ].each do |query, result|
      command = Pod::Command.parse('search', '--silent', '--full', query)
      def command.puts(msg = '')
        (@printed ||= '') << "#{msg}\n"
      end
      command.run
      printed = command.instance_variable_get(:@printed)
      printed.should == result
    end
  end
end
