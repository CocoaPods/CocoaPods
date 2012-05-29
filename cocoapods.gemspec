# -*- encoding: utf-8 -*-
require File.expand_path('../lib/cocoapods', __FILE__)

Gem::Specification.new do |s|
  s.name     = "cocoapods"
  s.version  = Pod::VERSION
  s.date     = Date.today
  s.license  = "MIT"
  s.email    = "eloy.de.enige@gmail.com"
  s.homepage = "https://github.com/CocoaPods/CocoaPods"
  s.authors  = ["Eloy Duran"]

  s.summary     = "An Objective-C library package manager."
  s.description = "CocoaPods manages library dependencies for your Xcode project.\n\n"     \
                  "You specify the dependencies for your project in one easy text file. "  \
                  "CocoaPods resolves dependencies between libraries, fetches source "     \
                  "code for the dependencies, and creates and maintains an Xcode "         \
                  "workspace to build your project.\n\n"                                   \
                  "Ultimately, the goal is to improve discoverability of, and engagement " \
                  "in, third party open-source libraries, by creating a more centralized " \
                  "ecosystem."

  s.files = Dir["lib/**/*.rb"] + %w{ bin/pod README.md LICENSE CHANGELOG.md }

  s.executables   = %w{ pod }
  s.require_paths = %w{ lib }

  s.post_install_message = "[!] If this is your first time install of CocoaPods, or if " \
                           "you are upgrading, first run: $ pod setup"

  s.add_runtime_dependency 'faraday',   '~> 0.8.1'
  s.add_runtime_dependency 'octokit',   '~> 1.3.0'

  s.add_runtime_dependency 'colored',   '~> 1.2'
  s.add_runtime_dependency 'escape',    '~> 0.0.4'
  s.add_runtime_dependency 'json',      '~> 1.7.3'
  s.add_runtime_dependency 'open4',     '~> 1.3.0'
  s.add_runtime_dependency 'rake',      '~> 0.9.0'
  s.add_runtime_dependency 'xcodeproj', '~> 0.1.0' # TODO update to RC1 for 0.6.0.rc1

  s.add_development_dependency 'bacon', '~> 1.1'

  ## Make sure you can build the gem on older versions of RubyGems too:
  s.rubygems_version = "1.6.2"
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.specification_version = 3 if s.respond_to? :specification_version
end
