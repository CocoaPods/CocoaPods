# -*- encoding: utf-8 -*-
require File.expand_path('../lib/cocoapods', __FILE__)

Gem::Specification.new do |s|
  s.name     = "cocoapods"
  s.version  = Pod::VERSION
  s.date     = "2011-09-17"
  s.license  = "MIT"
  s.email    = "eloy.de.enige@gmail.com"
  s.homepage = "https://github.com/alloy/cocoapods"
  s.authors  = ["Eloy Duran"]

  s.summary     = "A simple Objective-C library package manager. (Requires MacRuby.)"
  s.description = "CocoaPods is an Objective-C library package manager. It tries " \
                  "to take away all hard work of maintaining your dependencies, " \
                  "but in a lean and flexible way. Its goal is to create a more " \
                  "centralized overview of open-source libraries and unify the way " \
                  "in which we deal with them.\n" \
                  "CocoaPods will calculate the right set of versions of all of your " \
                  "project's dependencies, install them, and set them up to be build " \
                  "as part of a dependency static library, which your project links " \
                  "against."

  s.files    = Dir["lib/**/*.rb"] +
               %w{ bin/pod README.md LICENSE }

  s.executables   = %w{ pod }
  s.require_paths = %w{ lib }

  s.post_install_message = "To speed up load time of CocoaPods consider compiling the Ruby source files:\n\n" \
                           "    $ sudo macgem install rubygems-compile\n" \
                           "    $ sudo macgem compile cocoapods\n\n"

  s.add_runtime_dependency 'xcodeproj', '~> 0.0.1'

  ## Make sure you can build the gem on older versions of RubyGems too:
  s.rubygems_version = "1.6.2"
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.specification_version = 3 if s.respond_to? :specification_version
end
