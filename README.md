CocoaPods
---------

CocoaPods is an Objective-C library package manager. It tries to take away all
hard work of maintaining your dependencies, but in a lean and flexible way.

CocoaPods will:

* Calculate the right set of versions of all of your project’s dependencies.
* Install dependencies.
* Set them up to be build as part of a ‘dependency’ static library, which your
  project links against.


Installing CocoaPods
====================

You’ll need MacRuby. CocoaPods itself installs through RubyGems, the Ruby
package manager:

    $ brew install macruby [TODO There's actually no MacRuby homebrew formula]
    $ macgem install cocoa-pods
    $ pod setup


Making a Pod
============

A manifest that describes the library and its dependencies is called a Pod.
Consider you want to create a new library that retrieves the latest price of
your favorite ice cream called IcePop.

    $ pod spec create IcePop
    $ cd IcePop
    $ tree .
      - IcePop
      |- IcePop.podspec
      |- LICENSE
      |- README
      |\ Source
      | | - IcePop.h
      | | - IcePop.m
      |- Test

You can also initialize a Pod for an existing library, which will only create a
`.podspec` file.

    $ cd IcePop
    $ pod spec init IcePop


Anatomy of a PodSpec manifest
=============================

    class IcePop < Pod::Spec
      version    '1.0.0'                                                                  # 1
      summary    'A library that retrieves the current price of your favorite ice cream.' # 2
      author     'Eloy Durán' => 'eloy.de.enige@gmail.com'                                # 3
      source     :git => 'https://github.com/alloy/ice-pop.git'                           # 4
      dependency 'AsyncSocket', '~> 0.6'                                                  # 5
    end

1. The version of this pod.
2. A short summary of this pod’s description.
3. The author of this pod and his/her email address.
4. Where to retrieve this pod’s source.
5. Defines a dependency of the library itself, with a version requirement
   of 0.6 trough 0.9.

See the [example PodSpec manifest][example] for a full list of the available
attributes and more info.


Sharing a Pod
=============

CocoaPod uses git repositories with `.podspec` files as its database. In order
to share your pod, its `.podspec` file will have to be added to such a repo.
CocoaPod provides commands to facilitate this:

    $ pod repo add my-spec-repo http://github.com/alloy/spec-repo.git
    $ pod push my-spec-repo

This will:

1. Validate the `.podspec` file.
1. Update the clone of the local spec-repo called `my-spec-repo`.
2. Add the `.podspec` file to the spec-repo, namespaced by name and version.
3. Push the changes from the local spec-repo to its remote.


Share with everyone
===================

CocoaPods, itself, has a [spec-repo][http://github.com/alloy/cocoa-pod-specs],
called the ‘master’ spec-repo. This repo is meant as a central public place for
any open-source pod. All installations of CocoaPods will have a local clone of
this repo.

However, normally you will have read-only access only. Thus to get a PodSpec
into the ‘master’ spec-repo you will have to push to your own fork and send
a pull request.

Once your first PodSpec has been merged, you will be given push access to the
‘master’ spec-repo and are allowed to update and add `.podspec` files at your
own leisure.

Once you receive push acces, you will have to change your `master` spec-repo’s
remote URL with:

    $ pod repo change master https://github.com/alloc/cocoa-pod-specs.git # TODO real URL


[example]: PodSpec.example.rb
