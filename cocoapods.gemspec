# -*- encoding: utf-8 -*-
require File.expand_path('../lib/cocoapods', __FILE__)

Gem::Specification.new do |s|
  s.name     = "cocoapods"
  s.version  = Pod::VERSION
  s.date     = "2011-09-17"
  s.license  = "MIT"
  s.summary  = "A simple Objective-C library package manager. (Requires MacRuby.)"
  s.email    = "eloy.de.enige@gmail.com"
  s.homepage = "https://github.com/alloy/cocoapods"
  s.authors  = ["Eloy Duran"]

  s.files    = Dir["lib/**/*.rb"] +
               Dir["xcode-project-templates/**/*.*"] +
               %w{ bin/pod README.md LICENSE }

  s.executables   = %w{ pod }
  s.require_paths = %w{ lib }

  s.post_install_message = "To speed up load time of cocoapods consider compiling the Ruby source files:\n\n" \
                           "    $ sudo macgem install rubygems-compile\n" \
                           "    $ sudo macgem compile cocoapods\n\n"

  ## Make sure you can build the gem on older versions of RubyGems too:
  s.rubygems_version = "1.6.2"
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.specification_version = 3 if s.respond_to? :specification_version
end
