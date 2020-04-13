require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe UserInterface::ErrorReport do
    extend SpecHelper::TemporaryRepos

    def remove_color(string)
      string.gsub(/\e\[(\d+)m/, '')
    end

    describe 'In general' do
      before do
        @exception = Informative.exception('at - (~/code.rb):')
        @exception.stubs(:backtrace).returns(['Line 1', 'Line 2'])
        @report = UserInterface::ErrorReport
        set_up_test_repo
        config.repos_dir = SpecHelper.tmp_repos_path
        Pod::TrunkSource.any_instance.stubs(:refresh_metadata)
        FileUtils.mkdir_p(SpecHelper.tmp_repos_path.join('trunk'))
        FileUtils.cp(fixture('spec-repos/trunk').join('.url'), SpecHelper.tmp_repos_path.join('trunk/.url'))
      end

      it 'returns a well-structured report' do
        master = stub('master',
                      :url => 'https://github.com/CocoaPods/Specs.git', :repo => SpecHelper.tmp_repos_path.join('master'),
                      :git? => true)
        sources = [
          master,
          Pod::TrunkSource.new(SpecHelper.tmp_repos_path.join('trunk')),
        ]
        @report.stubs(:git_hash).returns('ABCD')
        config.sources_manager.stubs(:all).returns(sources)
        expected = <<-EOS

――― MARKDOWN TEMPLATE ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

### Command

```
/usr/bin/command arg1 arg2
```

### Report

* What did you do?

* What did you expect to happen?

* What happened instead?


### Stack

```
   CocoaPods : #{Pod::VERSION}
        Ruby : #{RUBY_DESCRIPTION}
    RubyGems : #{Gem::VERSION}
        Host : :host_information
       Xcode : :xcode_information
         Git : :git_information
Ruby lib dir : #{RbConfig::CONFIG['libdir']}
Repositories : master - git - https://github.com/CocoaPods/Specs.git @ ABCD
               trunk - CDN - #{Pod::TrunkSource::TRUNK_REPO_URL}
```

### Plugins

```
cocoapods         : #{Pod::VERSION}
cocoapods-core    : #{Pod::VERSION}
cocoapods-plugins : 1.2.3
```

### Podfile

```ruby

```

### Error

```
Pod::Informative - [!] at - (~/code.rb):
Line 1
Line 2
```

――― TEMPLATE END ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

[!] Oh no, an error occurred.

Search for existing GitHub issues similar to yours:
https://github.com/CocoaPods/CocoaPods/search?q=%5B%21%5D+at+-&type=Issues

If none exists, create a ticket, with the template displayed above, on:
https://github.com/CocoaPods/CocoaPods/issues/new

Be sure to first read the contributing guide for details on how to properly submit a ticket:
https://github.com/CocoaPods/CocoaPods/blob/master/CONTRIBUTING.md

Don't forget to anonymize any private data!

EOS
        @report.stubs(:markdown_podfile).returns <<-EOS

### Podfile

```ruby

```
EOS
        @report.stubs(:host_information).returns(':host_information')
        @report.stubs(:xcode_information).returns(':xcode_information')
        @report.stubs(:git_information).returns(':git_information')
        @report.stubs(:installed_plugins).returns('cocoapods' => Pod::VERSION,
                                                  'cocoapods-core' => Pod::VERSION,
                                                  'cocoapods-plugins' => '1.2.3')
        @report.stubs(:original_command).returns('/usr/bin/command arg1 arg2')
        report = remove_color(@report.report(@exception))
        report.should == expected
      end

      it 'strips the local path from the exception message' do
        message = @report.send(:pathless_exception_message, @exception.message)
        message = remove_color(message)
        message.should == '[!] at -'
      end

      it 'handles inspector_successfully_received_report' do
        time = Time.new(2016, 5, 13)
        Time.stubs(:now).returns(time)

        url = 'https://api.github.com/search/issues?q=Testing+repo:cocoapods/cocoapods'
        fixture_json_text = File.read SpecHelper.fixture('github_search_response.json')
        GhInspector::Sidekick.any_instance.expects(:get_api_results).with(url).returns(JSON.parse(fixture_json_text))

        error = NameError.new('Testing', 'orta')
        @report.search_for_exceptions error
        result = <<-EOS
Looking for related issues on cocoapods/cocoapods...
 - Travis CI with Ruby 1.9.x fails for recent pull requests
   https://github.com/CocoaPods/CocoaPods/issues/646 [closed] [8 comments]
   14 Nov 2012

 - pod search --full chokes on cocos2d.podspec:14
   https://github.com/CocoaPods/CocoaPods/issues/657 [closed] [1 comment]
   20 Nov 2012

 - about pod
   https://github.com/CocoaPods/CocoaPods/issues/4345 [closed] [21 comments]
   2 weeks ago

and 30 more at:
https://github.com/cocoapods/cocoapods/search?q=Testing&type=Issues&utf8=✓
EOS
        UI.output.should == result
      end

      it 'doesn\'t crash on non UTF-8 error message' do
        should.not.raise(Encoding::CompatibilityError) do
          @exception.stubs(:message).returns('”ASCII-8BIT”'.force_encoding('ASCII-8BIT'))
          @report.report(@exception)
        end
      end
    end
  end
end
