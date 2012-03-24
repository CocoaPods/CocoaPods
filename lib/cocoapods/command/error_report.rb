require 'rbconfig'
require 'cgi'
require 'rubygems'

module Pod
  class Command
    module ErrorReport
      class << self
        def report(error)
          return <<-EOS
Oh no, an error occurred. #{error_from_podfile(error)}

Search for existing github issues similar to yours:

  https://github.com/CocoaPods/CocoaPods/issues/search?q=%22#{CGI.escape(error.message)}%22

If none exists, create a ticket with the following information to:

  https://github.com/CocoaPods/CocoaPods/issues/new

Don't forget to anonymize any private data!


### Stack

* Host version: #{host_information}
* Xcode version: #{xcode_information}
* Ruby version: #{RUBY_DESCRIPTION}
* Ruby lib dir: #{RbConfig::CONFIG['libdir']}
* RubyGems version: #{Gem::VERSION}
* CocoaPods version: #{Pod::VERSION}
* Specification repositories:
  - #{repo_information.join("\n  - ")}


### Podfile

```ruby
#{Config.instance.project_podfile.read if Config.instance.project_podfile}
```


### Error

```
#{error.message}
  #{error.backtrace.join("\n  ")}
```
EOS
        end

        private

        def error_from_podfile(error)
          if error.message =~ /Podfile:(\d*)/
            "It appears to have originated from your Podfile at line #{$1}."
          end
        end

        def host_information
          product, version, build =`sw_vers`.strip.split("\n").map { |line| line.split(":").last.strip }
          "#{product} #{version} (#{build})"
        end

        def xcode_information
          version, build = `xcodebuild -version`.strip.split("\n").map { |line| line.split(" ").last }
          "#{version} (#{build})"
        end

        def repo_information
          Pod::Source.all.map do |source|
            repo = source.repo
            Dir.chdir(repo) do
              url = `git config --get remote.origin.url`.strip
              sha = `git rev-parse HEAD`.strip
              "#{repo.basename} - #{url} @ #{sha}"
            end
          end
        end
      end
    end
  end
end
