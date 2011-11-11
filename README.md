# CocoaPods – an Objective-C library manager

CocoaPods manages library dependencies for your Xcode project.

You specify the dependencies for your project in one easy text file. CocoaPods resolves dependencies between libraries, fetches source code for the dependencies, and creates and maintains an Xcode workspace to build your project.

Ultimately, the goal is to improve discoverability of, and engagement in, third party open-source libraries, by creating a more centralized ecosystem.

See [the wiki](https://github.com/alloy/cocoapods/wiki) for more in depth information on several topics.


## Installation

Downloading and installing CocoaPods only takes a few minutes.

CocoaPods runs on [MacRuby](http://macruby.org). If you don't have a recent version of MacRuby installed you will need to download it. CocoaPods works best on version 0.10.

    $ curl -O http://www.macruby.org/files/MacRuby%200.10.zip
    $ open MacRuby%200.10.zip
    # open MacRuby\ 0.10/MacRuby\ 0.10.pkg

After that you can install CocoaPods itself.

    $ sudo macgem install cocoapods
    $ pod setup

Now that you've got CocoaPods installed you can easily add it to your project.


## Adding it to your project

Search for Pods by name or description.

    $ pod search asi
    ==> ASIHTTPRequest (1.8.1)
        Easy to use CFNetwork wrapper for HTTP requests, Objective-C, Mac OS X and iPhone
    
    ==> ASIWebPageRequest (1.8.1)
        The ASIWebPageRequest class included with ASIHTTPRequest lets you download
        complete webpages, including external resources like images and stylesheets.

After you've found your favorite dependencies you add them to your [Podfile](https://github.com/alloy/cocoapods/wiki/A-Podfile).

    $ edit Podfile
    platform :ios
    dependency 'JSONKit',           '~> 1.4'
    dependency 'Reachability',      '~> 2.0.4'

And then you [install the dependencies](https://github.com/alloy/cocoapods/wiki/Creating-a-project-that-uses-CocoaPods) in your project.

    $ pod install App.xcodeproj

_Where ‘App.xcodeproj’ is the name of your actual application project._

Remember to always open the Xcode workspace instead of the project file when you're building.

    $ open App.xcworkspace

Sometimes CocoaPods doesn't have a Pod for one of your dependencies yet. Fortunately [creating a Pod](https://github.com/alloy/cocoapods/wiki/A-pod-specification) is really easy.

    $ pod spec create Peanuts
    $ edit Peanuts.podspec
    $ pod spec lint Peanuts.podspec

Once you've got it running [create a ticket](https://github.com/alloy/cocoapods/issues) and upload the Pod. If you're familiar with Git you can also fork the [CocoaPods specs](https://github.com/alloy/cocoapods-specs) repository and send a pull request. We really love contributions!

There are several other ways to start using **any** library without a Pod specification, which can be seen in the [SSCatalog example](https://github.com/alloy/cocoapods/blob/master/examples/SSCatalog/Podfile).


## Collaborate

All CocoaPods development happens on GitHub, there is a repository for [CocoaPods](https://github.com/alloy/cocoapods) and one for the [CocoaPods specs](https://github.com/alloy/cocoapods-specs). Contributing patches or Pods is really easy and gratifying. You even get push access when one of your specs or patches is accepted.

Follow [@CocoaPodsOrg](http://twitter.com/CocoaPodsOrg) to get up to date information about what's going on in the CocoaPods world.

If you're really oldschool and you want to discuss CocoaPods development you can join #cocoapods on irc.freenode.net.


# Endorsements

* “I am crazy excited about this. With the growing number of Objective-C libraries, this will make things so much better.” –– [Sam Soffes](http://news.ycombinator.com/item?id=3009154)
* “Are you doing open source iOS components? You really should support @CocoaPodsOrg!” –– [Matthias Tretter](http://twitter.com/#!/myell0w/status/134955697740840961)
* “So glad someone has finally done this...” –– [Tom Wilson](http://news.ycombinator.com/item?id=3009349)
* “Anybody who has tasted the coolness of RubyGems (and @gembundler) understands how cool CocoaPods might be.” –– [StuFF mc](http://twitter.com/#!/stuffmc/status/115374231591731200)
* “I will be working on getting several of my Objective-C libraries ready for CocoaPods this week!” –– [Luke Redpath](http://twitter.com/#!/lukeredpath/status/115510581921988608)
* “Really digg how @alloy is building a potential game changer” –– [Klaas Speller](https://twitter.com/#!/spllr/status/115914209438601216)
* “This is awesome, I love endorsements!” –– [Appie Durán](http://twitter.com/#!/AppieDuran)
