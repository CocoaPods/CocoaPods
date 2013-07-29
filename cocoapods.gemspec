# encoding: UTF-8
require File.expand_path('../lib/cocoapods/gem_version', __FILE__)
require 'date'

Gem::Specification.new do |s|
  s.name     = "cocoapods"
  s.version  = Pod::VERSION
  s.date     = Date.today
  s.license  = "MIT"
  s.email    = ["eloy.de.enige@gmail.com", "fabiopelosin@gmail.com"]
  s.homepage = "https://github.com/CocoaPods/CocoaPods"
  s.authors  = ["Eloy Duran", "Fabio Pelosin"]

  s.summary     = "An Objective-C library package manager."
  s.description = "CocoaPods manages library dependencies for your Xcode project.\n\n"     \
                  "You specify the dependencies for your project in one easy text file. "  \
                  "CocoaPods resolves dependencies between libraries, fetches source "     \
                  "code for the dependencies, and creates and maintains an Xcode "         \
                  "workspace to build your project.\n\n"                                   \
                  "Ultimately, the goal is to improve discoverability of, and engagement " \
                  "in, third party open-source libraries, by creating a more centralized " \
                  "ecosystem."

s.files = Dir["lib/**/*.rb"] + %w{ bin/pod bin/sandbox-pod README.md LICENSE CHANGELOG.md }

  s.executables   = %w{ pod sandbox-pod }
  s.require_paths = %w{ lib }

  # Link with the version of CocoaPods-Core
  s.add_runtime_dependency 'cocoapods-core',       "= #{Pod::VERSION}"
  s.add_runtime_dependency 'claide',               '~> 0.3.2'
  s.add_runtime_dependency 'cocoapods-downloader', '~> 0.1.1'
  s.add_runtime_dependency 'xcodeproj',            '~> 0.8.1'

  s.add_runtime_dependency 'colored',       '~> 1.2'
  s.add_runtime_dependency 'escape',        '~> 0.0.4'
  s.add_runtime_dependency 'json',          '~> 1.8.0'
  s.add_runtime_dependency 'open4',         '~> 1.3.0'
  s.add_runtime_dependency 'activesupport', '~> 3.2.13'

  s.add_development_dependency 'bacon', '~> 1.1'

  ## Make sure you can build the gem on older versions of RubyGems too:
  s.rubygems_version = "1.6.2"
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = '>= 1.8.7'
  s.specification_version = 3 if s.respond_to? :specification_version

  changelog_path = File.expand_path('../CHANGELOG.md', __FILE__)
  if File.exists?(changelog_path)
    title_token = '## '
    current_verison_title = title_token +  Pod::VERSION.to_s
    text = File.open(changelog_path, "r:UTF-8") { |f| f.read }
    lines = text.split("\n")

    current_version_index = lines.find_index { |line| line =~ (/^#{current_verison_title}/) }
    previous_version_lines = lines[(current_version_index+1)...-1]
    previous_version_index = current_version_index + previous_version_lines.find_index { |line| line =~ (/^#{title_token}/) && !line.include?('rc') }

    relevant = lines[current_version_index..previous_version_index]

    s.post_install_message = "\nCHANGELOG:\n\n" + relevant.join("\n") + "\n"
  end
end
