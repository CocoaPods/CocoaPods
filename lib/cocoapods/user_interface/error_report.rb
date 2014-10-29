# encoding: UTF-8

require 'rbconfig'
require 'cgi'

module Pod
  module UserInterface
    module ErrorReport
      class << self
        def report(exception)
          <<-EOS

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
         Git : #{git_information}
Ruby lib dir : #{RbConfig::CONFIG['libdir']}
Repositories : #{repo_information.join("\n               ")}
```

### Plugins

```
#{plugins_string}
```
#{markdown_podfile}
### Error

```
#{exception.class} - #{exception.message}
#{exception.backtrace.join("\n")}
```

#{'――― TEMPLATE END ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――'.reversed}

#{'[!] Oh no, an error occurred.'.red}
#{error_from_podfile(exception)}
#{'Search for existing github issues similar to yours:'.yellow}
#{issues_url(exception)}

#{'If none exists, create a ticket, with the template displayed above, on:'.yellow}
https://github.com/CocoaPods/CocoaPods/issues/new

#{'Be sure to first read the contributing guide for details on how to properly submit a ticket:'.yellow}
https://github.com/CocoaPods/CocoaPods/blob/master/CONTRIBUTING.md

Don't forget to anonymize any private data!

EOS
        end

        private

        def pathless_exception_message(message)
          message.gsub(/- \(.*\):/, '-')
        end

        def markdown_podfile
          return '' unless Config.instance.podfile_path && Config.instance.podfile_path.exist?
          <<-EOS

### Podfile

```ruby
#{Config.instance.podfile_path.read.strip}
```
EOS
        end

        def error_from_podfile(error)
          if error.message =~ /Podfile:(\d*)/
            "\nIt appears to have originated from your Podfile at line #{Regexp.last_match[1]}.\n"
          end
        end

        def remove_color(string)
          string.gsub(/\e\[(\d+)m/, '')
        end

        def issues_url(exception)
          message = remove_color(pathless_exception_message(exception.message))
          'https://github.com/CocoaPods/CocoaPods/search?q=' \
          "#{CGI.escape(message)}&type=Issues"
        end

        def host_information
          product, version, build = `sw_vers`.strip.split("\n").map { |line| line.split(':').last.strip }
          "#{product} #{version} (#{build})"
        end

        def xcode_information
          version, build = `xcodebuild -version`.strip.split("\n").map { |line| line.split(' ').last }
          "#{version} (#{build})"
        end

        def git_information
          `git --version`.strip.split("\n").first
        end

        def installed_plugins
          CLAide::Command::PluginsHelper.specifications.
            reduce({}) { |hash, s| hash.tap { |h| h[s.name] = s.version.to_s } }
        end

        def plugins_string
          plugins = installed_plugins
          max_name_length = plugins.keys.map(&:length).max
          plugins.map do |name, version|
            "#{name.ljust(max_name_length)} : #{version}"
          end.sort.join("\n")
        end

        def repo_information
          SourcesManager.all.map do |source|
            next unless source.type == 'file system'
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
