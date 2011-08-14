CocoaPods
---------

CocoaPods is an Objective-C library package manager. It tries to take away all
hard work of maintaining your dependencies, but in a lean and flexible way.

Its goal is to create a more centralized overview of open-source libraries and
unify the way in which we deal with them.

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

See the [example PodSpec file][example] for a full list of the available
attributes and more detailed information.


Sharing a Pod
=============

CocoaPod uses git repositories with `.podspec` files as its database. In order
to share your pod, its `.podspec` file will have to be added to such a repo.

    $ pod repo add my-spec-repo http://github.com/alloy/spec-repo.git
    $ pod push my-spec-repo

This will:

1. Validate the `.podspec` file.
1. Update the clone of the local spec-repo called `my-spec-repo`.
2. Add the `.podspec` file to the spec-repo, namespaced by name and version.
3. Push the changes from the local spec-repo to its remote.


Share with everyone
===================

CocoaPods, itself, has a [spec-repo][master], called the `master` spec-repo.
This repo is meant as a central public place for any open-source pod. All
installations of CocoaPods will have a local clone of this repo.

However, normally you will have read-only access only. Thus to get a PodSpec
into the `master` spec-repo you will have to push to your own fork and send
a pull request.

Once your first PodSpec has been merged, you will be given push access to the
`master` spec-repo and are allowed to update and add `.podspec` files at your
own leisure.

Once you receive push acces, you will have to change your `master` spec-repo’s
remote URL with:

    $ pod repo change master git@github.com:alloy/cocoa-pod-specs.git


Commands overview
=================

### Setup

    $ pod help setup

      pod setup
        Creates a directory at `~/.cocoa-pods' which will hold your spec-repos.
        This is where it will create a clone of the public `master' spec-repo.

### Managing PodSpec files

    $ pod help spec

      pod spec create NAME
        Creates a directory for your new pod, named `NAME', with a default
        directory structure and accompanying `NAME.podspec'.

      pod spec init NAME
        Creates a PodSpec, in the current working dir, called `NAME.podspec'.
        Use this for existing libraries.

      pod spec lint NAME
        Validates `NAME.podspec' from a local spec-repo. In case `NAME' is
        omitted, it defaults to the PodSpec in the current working dir.

      pod spec push REMOTE
        Validates `NAME.podspec' in the current working dir, copies it to the
        local clone of the `REMOTE' spec-repo, and pushes it to the `REMOTE'
        spec-repo. In case `REMOTE' is omitted, it defaults to `master'.

### Managing spec-repos

    $ pod help repo

      pod repo add NAME URL
        Clones `URL' in the local spec-repos directory at `~/.cocoa-pods'. The
        remote can later be referred to by `NAME'.

      pod repo update NAME
        Updates the local clone of the spec-repo `NAME'.

      pod repo change NAME URL
        Changes the git remote of local spec-repo `NAME' to `URL'.

      pod repo cd NAME
        Changes the current working dir to the local spec-repo `NAME'.


Contact
=======

Eloy Durán:

* http://github.com/alloy
* http://twitter.com/alloy
* eloy.de.enige@gmail.com


LICENSE
=======

These works are available under the MIT license. See the [LICENSE][license] file
for more info.


[license]: cocoa-pods/blob/master/LICENSE
[example]: cocoa-pods/blob/master/examples/PodSpec.podspec
[master]: http://github.com/alloy/cocoa-pod-specs
