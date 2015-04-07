![CocoaPods Logo](https://raw.github.com/CocoaPods/shared_resources/master/assets/cocoapods-banner-readme.png)

### CocoaPods: The Cocoa dependency manager

[![Build Status](http://img.shields.io/travis/CocoaPods/CocoaPods/master.svg?style=flat)](https://travis-ci.org/CocoaPods/CocoaPods)
[![Gem Version](http://img.shields.io/gem/v/cocoapods.svg?style=flat)](http://badge.fury.io/rb/cocoapods)
[![Code Climate](http://img.shields.io/codeclimate/github/CocoaPods/CocoaPods.svg?style=flat)](https://codeclimate.com/github/CocoaPods/CocoaPods)

CocoaPods manages dependencies for your Xcode projects.

You specify the dependencies for your project in one easy text file. CocoaPods
resolves dependencies between libraries, fetches source code for the
dependencies, and creates and maintains an Xcode workspace to build your
project.

Installing and updating CocoaPods is very easy. Don't miss the [Installation
guide](http://guides.cocoapods.org/using/getting-started.html#installation) and the
[Getting started guide](https://guides.cocoapods.org/using/getting-started.html).

## Project Goals

Ultimately, the goal of CocoaPods is to improve the engagement in, and
discoverability of, third party open-source libraries. The following list
includes the project goals which have influenced, and continues to
drive the design of CocoaPods.

- Being able to work in the system without creating extra work for
  library authors. Making it possible to maintain a simple transparent
  podspec outside of the library’s repository.
- Not imposing any judgement of ‘correctness’ on how authors decide to
  structure their library.
- CocoaPods should not impose any specific requirements on source-code
  management systems. (Currently supported are git, svn, mercurial, bazaar, and
  various types of archives downloaded over HTTP.)
- Provide the ability to work in a distributed way, but also provide
  features only possible with a centralised solution to foster a community.
- Being able to build tools on top of the system, including those typically
  deployed to other operating systems, such as web-services.
- Providing opinionated and automated integration, but making that completely
  optional. It’s perfectly possible to manually integrate the CocoaPods
  Xcode project as you see fit, with or without a workspace.
- Not depending on Apple to fix issues with Xcode or otherwise force
  authors to have to do a lot of Xcode work not related to their
  library’s functionality.

## Sponsors

Lovingly sponsored by a collection of companies, see the footer of [CocoaPods.org](https://cocoapods.org) for an up-to-date list. 

## Collaborate

All CocoaPods development happens on GitHub. Contributions make for good karma and
we [welcome new](https://blog.cocoapods.org/starting-open-source/) contributors with joy. We take contributors seriously, and thus have a 
contributor [code of conduct](CODE_OF_CONDUCT.md).

## Links

| Link | Description |
| :----- | :------ |
[CocoaPods.org](https://cocoapods.org/) | Homepage and search for Pods.
[@CocoaPods](https://twitter.com/CocoaPods) | Follow CocoaPods on Twitter to stay up to date.
[Blog](https://blog.cocoapods.org) | The CocoaPods blog.
[Mailing List](http://groups.google.com/group/cocoapods) | Feel free to ask any kind of question.
[Guides](https://guides.cocoapods.org) | Everything you want to know about CocoaPods.
[Changelog](https://github.com/CocoaPods/CocoaPods/blob/master/CHANGELOG.md) | See the changes introduced in each CocoaPods version.
[New Pods RSS](https://feeds.cocoapods.org/new-pods.rss) | Don't miss any new Pods.
[Code of Conduct](CODE_OF_CONDUCT.md) | Find out the standards we hold ourselves to.

## Projects

CocoaPods is composed of the following projects:

| Status | Project | Description | Info |
| :----- | :------ | :--- | :--- |
| [![Build Status](http://img.shields.io/travis/CocoaPods/CocoaPods/master.svg?style=flat)](http://travis-ci.org/CocoaPods/CocoaPods) | [CocoaPods](https://github.com/CocoaPods/CocoaPods) | The CocoaPods command line tool. | [guides](https://guides.cocoapods.org)
| [![Build Status](http://img.shields.io/travis/CocoaPods/Core/master.svg?style=flat)](http://travis-ci.org/CocoaPods/Core) | [CocoaPods Core](https://github.com/CocoaPods/Core) | Support for working with specifications and podfiles. | [docs](http://docs.cocoapods.org/cocoapods_core)
| [![Build Status](http://img.shields.io/travis/CocoaPods/cocoapods-downloader/master.svg?style=flat)](http://travis-ci.org/CocoaPods/cocoapods-downloader) |[CocoaPods Downloader](https://github.com/CocoaPods/cocoapods-downloader) |  Downloaders for various source types. |  [docs](http://docs.cocoapods.org/cocoapods_downloader/index.html)
| [![Build Status](http://img.shields.io/travis/CocoaPods/Xcodeproj/master.svg?style=flat)](https://travis-ci.org/CocoaPods/Xcodeproj) | [Xcodeproj](https://github.com/CocoaPods/Xcodeproj) | Create and modify Xcode projects from Ruby. |  [docs](http://docs.cocoapods.org/xcodeproj/index.html)
| [![Build Status](http://img.shields.io/travis/CocoaPods/CLAide/master.svg?style=flat)](https://travis-ci.org/CocoaPods/CLAide) | [CLAide](https://github.com/CocoaPods/CLAide) | A small command-line interface framework.  | [docs](http://docs.cocoapods.org/claide/index.html)
| [![Build Status](http://img.shields.io/travis/CocoaPods/Molinillo/master.svg?style=flat)](https://travis-ci.org/CocoaPods/Molinillo) | [Molinillo](https://github.com/CocoaPods/Molinillo) | A powerful generic dependency resolver.  | [docs](http://www.rubydoc.info/gems/molinillo)
|  | [Master Repo ](https://github.com/CocoaPods/Specs) | Master repository of specifications. | [guide](http://docs.cocoapods.org/guides/contributing_to_the_master_repo.html)
