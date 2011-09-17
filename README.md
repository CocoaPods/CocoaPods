# CocoaPods

CocoaPods is an Objective-C library package manager. It tries to take away all
hard work of maintaining your dependencies, but in a lean and flexible way.

Its goal is to create a more centralized overview of open-source libraries and
unify the way in which we deal with them.

CocoaPods will:

* Calculate the right set of versions of all of your project’s dependencies.
  _Currently the resolver is very naive and any conflicts will have to be solved
  by you, the user. This will change in the future._
* Install dependencies.
* Set them up to be build as part of a ‘dependency’ static library, which your
  project links against.

For more in depth information see the [wiki][wiki].


## Installing CocoaPods

You’ll need MacRuby. CocoaPods itself installs through RubyGems, the Ruby
package manager:

    $ brew install macruby
    $ macgem install cocoapods
    $ pod setup


## Contact

Eloy Durán:

* http://github.com/alloy
* http://twitter.com/alloy
* eloy.de.enige@gmail.com


## LICENSE

These works are available under the MIT license. See the [LICENSE][license] file
for more info.


[wiki]: https://github.com/alloy/cocoapods/wiki
[license]: cocoa-pods/blob/master/LICENSE
