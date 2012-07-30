# encoding: UTF-8

require 'rbconfig'
require 'cgi'

module Pod
  class Command
    module ErrorReport
      class << self
        def report(error)
          return <<-EOS

          #{'――― MARKDOWN TEMPLATE ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――'.reversed}

### Report

* What did you do?

* What did you expect to happen?

* What happened instead?


### Stack

```
   CocoaPods : #{Pod::VERSION}
        Ruby : #{RUBY_DESCRIPTION}
    RubyGems : #{Gem::VERSION}
        Host : #{host_information}
       Xcode : #{xcode_information}
Ruby lib dir : #{RbConfig::CONFIG['libdir']}
Repositories : #{repo_information.join("\n               ")}
```
#{markdown_podfile}
### Error

```
#{error.message}
#{error.backtrace.join("\n")}
```

#{'――― TEMPLATE END ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――'.reversed}

#{'[!] Oh no, an error occurred.'.red}
#{error_from_podfile(error)}
#{'Search for existing github issues similar to yours:'.yellow}
#{"https://github.com/CocoaPods/CocoaPods/issues/search?q=#{CGI.escape(error.message)}"}

#{'If none exists, create a ticket, with the template displayed above, on:'.yellow}
https://github.com/CocoaPods/CocoaPods/issues/new

Don't forget to anonymize any private data!

EOS
        end

        private

        def markdown_podfile
          return '' unless Config.instance.project_podfile && Config.instance.project_podfile.exist?
          <<-EOS

### Podfile

```ruby
          #{Config.instance.project_podfile.read.strip}
```
          EOS
        end

        def error_from_podfile(error)
          if error.message =~ /Podfile:(\d*)/
            "\nIt appears to have originated from your Podfile at line #{$1}.\n"
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
              url = `git config --get remote.origin.url 2>&1`.strip
              sha = `git rev-parse HEAD 2>&1`.strip
              "#{repo.basename} - #{url} @ #{sha}"
            end
          end
        end
      end
    end
  end
end
