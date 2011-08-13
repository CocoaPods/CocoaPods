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

* Automatically add files from lib manifest to Xcode project, but can be skipped

* Calculate dependencies across a set of libraries like bundler

* Wizard to create a manifest

* Has git submodules which contain the actual manifests


Manifest
--------

* Is a runnable ruby file

* Inherits from a base class that provides install strategies


Other managers
--------------

Kit: https://github.com/nkpart/kit

1. Has to fork repos to change directory structure and add KitSpec
2. Has good strategy for the way it add dependencies to the project
3. Uses haskell, so does not have easy access to ways to manipulate plists (Xcode project) and leaves configuring of project up to user.
4. Uses JSON for manifest. While simple, it does not allow for a way to adapt the build process to the repo (see #1)
