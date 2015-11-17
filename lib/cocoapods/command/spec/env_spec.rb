require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Env do
    describe 'In general' do
      before do
        @report = Command::Env
      end

      it 'returns a well-structured environment report' do
        expected = <<-EOS

### Stack

```
   CocoaPods : #{Pod::VERSION}
        Ruby : #{RUBY_DESCRIPTION}
    RubyGems : #{Gem::VERSION}
        Host : :host_information
       Xcode : :xcode_information
         Git : :git_information
Ruby lib dir : #{RbConfig::CONFIG['libdir']}
Repositories : repo_1
               repo_2
```

### Installation Source

```
Executable Path: /usr/bin/command
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
EOS

        @report.stubs(:actual_path).returns('/usr/bin/command')
        report.should == expected
      end
    end
  end
end
