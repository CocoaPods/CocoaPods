What I want it to do
--------------------


Client
------

* Search libs

* Install libs plus dependencies

* Downloading of libs:
  - As a git vendor
  - Files (subset) from a git repo
  - Should be implemented in such a way that people can add support for, for instance, svn

* Automatically add files from lib manifest to Xcode project

* Calculate dependencies across a set of libraries like bundler

* Wizard to create a manifest

* Has git submodules which contain the actual manifests


Manifest
--------

* Is a runnable ruby file

* Inherits from a base class that provides install strategies

