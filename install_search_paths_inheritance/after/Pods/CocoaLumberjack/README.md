<p align="center" >
  <img src="LumberjackLogo.png" title="Lumberjack logo" float=left>
</p>

CocoaLumberjack
===============
[![Build Status](http://img.shields.io/travis/CocoaLumberjack/CocoaLumberjack/master.svg?style=flat)](https://travis-ci.org/CocoaLumberjack/CocoaLumberjack)
[![Pod Version](http://img.shields.io/cocoapods/v/CocoaLumberjack.svg?style=flat)](http://cocoadocs.org/docsets/CocoaLumberjack/)
[![Pod Platform](http://img.shields.io/cocoapods/p/CocoaLumberjack.svg?style=flat)](http://cocoadocs.org/docsets/CocoaLumberjack/)
[![Pod License](http://img.shields.io/cocoapods/l/CocoaLumberjack.svg?style=flat)](http://opensource.org/licenses/BSD-3-Clause)
[![Reference Status](https://www.versioneye.com/objective-c/cocoalumberjack/reference_badge.svg?style=flat)](https://www.versioneye.com/objective-c/cocoalumberjack/references)

**CocoaLumberjack** is a fast & simple, yet powerful & flexible logging framework for Mac and iOS.

#### Lumberjack is Fast & Simple, yet Powerful & Flexible.

It is similar in concept to other popular logging frameworks such as log4j, yet is designed specifically for Objective-C, and takes advantage of features such as multi-threading, grand central dispatch (if available), lockless atomic operations, and the dynamic nature of the Objective-C runtime.

#### Lumberjack is Fast

In most cases it is an order of magnitude faster than NSLog.

#### Lumberjack is Simple

It takes as little as a single line of code to configure lumberjack when your application launches. Then simply replace your NSLog statements with DDLog statements and that's about it. (And the DDLog macros have the exact same format and syntax as NSLog, so it's super easy.)

#### Lumberjack is Powerful:

One log statement can be sent to multiple loggers, meaning you can log to a file and the console simultaneously. Want more? Create your own loggers (it's easy) and send your log statements over the network. Or to a database or distributed file system. The sky is the limit.

#### Lumberjack is Flexible:

Configure your logging however you want. Change log levels per file (perfect for debugging). Change log levels per logger (verbose console, but concise log file). Change log levels per xcode configuration (verbose debug, but concise release). Have your log statements compiled out of the release build. Customize the number of log levels for your application. Add your own fine-grained logging. Dynamically change log levels during runtime. Choose how & when you want your log files to be rolled. Upload your log files to a central server. Compress archived log files to save disk space...

### This framework is for you if:

-   You're looking for a way to track down that impossible-to-reproduce bug that keeps popping up in the field.
-   You're frustrated with the super short console log on the iPhone.
-   You're looking to take your application to the next level in terms of support and stability.
-   You're looking for an enterprise level logging solution for your application (Mac or iPhone).

### How to get started
- install via [CocoaPods](http://cocoapods.org)

```ruby
platform :ios, '6.1'
pod 'CocoaLumberjack'
```
- read the [Getting started](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/GettingStarted) guide, check out the [FAQ](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/FAQ) section or the other [docs](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki)
- if you find issues or want to suggest improvements, create an issue or a pull request
- for all kinds of questions involving CocoaLumberjack, use the [Google group](http://groups.google.com/group/cocoalumberjack) or StackOverflow (use [#lumberjack](http://stackoverflow.com/questions/tagged/lumberjack)).

### Documentation
- **[Get started using Lumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/GettingStarted)**<br/>
- [Different log levels for Debug and Release builds](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/XcodeTricks)<br/>
- [Different log levels for each logger](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/PerLoggerLogLevels)<br/>
- [Use colors in the Xcode debugging console](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/XcodeColors)<br/>
- [Write your own custom formatters](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/CustomFormatters)<br/>
- [FAQ](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/FAQ)<br/>
- [Analysis of performance with benchmarks](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/Performance)<br/>
- [Common issues you may encounter and their solutions](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/ProblemSolution)<br/>
- [AppCode support](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/AppCode-support)
- **[full Lumberjack wiki](https://github.com/CocoaLumberjack/CocoaLumberjack/wiki)**<br/>

### Requirements 
- Xcode 4.4 or later is required
- iOS 5 or later
- OS X 10.7 or later
- for OS X < 10.7 support, use the 1.6.0 version

### Author
- [Robbie Hanson](https://github.com/robbiehanson)
- Love the project? Wanna buy me a coffee? (or a beer :D) [![donation](http://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=UZRA26JPJB3DA)

### Collaborators
- [Ernesto Rivera](https://github.com/rivera-ernesto)
- [Dmitry Vorobyov](https://github.com/dvor)
- [Bogdan Poplauschi](https://github.com/bpoplauschi)

### License
- CocoaLumberjack is available under the BSD license. See the [LICENSE file](https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/LICENSE.txt).
