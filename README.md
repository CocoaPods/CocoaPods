Installing CocoaPods
--------------------

You’ll need MacRuby. CocoaPods itself installs through RubyGems, the Ruby package manager:

    $ brew install macruby [TODO There's actually no MacRuby homebrew formula]
    $ macgem install cocoa-pods


Making a Pod
------------

A manifest that describes the library and its dependencies is called a Pod.
Consider you want to create a new library that retrieves the latest price of
your favorite ice cream called IcePop.

    $ pod create IcePop
    $ cd IcePop
    $ tree .
      - IcePop
      |- LICENSE
      |- PodSpec
      |- README
      |\ Source
      | | - IcePop.h
      | | - IcePop.m
      |- Test

You can also initialize a Pod for an existing library, which will only create a
PodSpec manifest.

    $ cd IcePop
    $ pod init


Anatomy of a PodSpec manifest
-----------------------------

    class IcePop < Pod::Spec
      # 1
      dependency 'AsyncSocket', '~> 0.6'

      # 2
      group :development do
        dependency 'FakeServer', '>= 1'
      end
    end

1. Defines a dependency of the library itself, with a version requirement of 0.6 trough 0.9.


See also
--------

* [Semantic versioning][http://semver.org]
