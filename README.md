# CocoaPods

CocoaPods is an Objective-C library package manager. It tries to take away all
hard work of maintaining your dependencies, but in a lean and flexible way.

Its goal is to create a more centralized overview of open-source libraries and
unify the way in which we deal with them, like RubyGems[http://rubygems.org]
does for the Ruby community.

CocoaPods will:

* Calculate the right set of versions of all of your project’s dependencies.
  _Currently the resolver is very naive and any conflicts will have to be solved
  by you, the user. This will change in the future._
* Install dependencies.
* Set them up to be build as part of a ‘dependency’ static library, which your
  project links against.

For more in depth information see the [wiki][wiki].


**_NOTE: At the moment [only iOS projects are supported][ticket], but this will
be fixed in the very near future._**

## Installing CocoaPods

You’ll need MacRuby. CocoaPods itself installs through RubyGems, the Ruby
package manager:

**_NOTE: There actually is no MacRuby homebrew formula yet, but it's being worked on as we speak, well, you reading this._**

    $ brew install macruby
    $ macgem install cocoapods
    $ pod setup

The load time can be improved a bit by compiling the Ruby source files:

    $ macgem install rubygems-compile
    $ macgem compile cocoapods


## Contributing

* We need specifications for as many libraries as possible, which will help in
  adoption and finding CocoaPods issues that need to be addressed.

* There needs to be [proper documentation and guides with screenshots][wiki],
  screencasts, blog posts, etcetera.

* The project is still very young, so there's a lot still on the table. Feel
  free to create [tickets][tickets] with ideas, feedback, and issues.

* If you're looking for other things to do, check the [tickets][tickets] and
  [the example specification][example-spec] which contains a lot of ideas we
  may, or may not, want to support.

**I will give out push access to the [cocoapods][cocoapods] and
[master spec-repo][cocoapods-specs] to anyone that has _one) patch accepted.**


## Contact

Eloy Durán:

* http://github.com/alloy
* http://twitter.com/alloy
* eloy.de.enige@gmail.com


## LICENSE

These works are available under the MIT license. See the [LICENSE][license] file
for more info.


[cocoapods]: https://github.com/alloy/cocoapods
[cocoapods-specs]: https://github.com/alloy/cocoapods-specs
[tickets]: https://github.com/alloy/cocoapods/issues
[ticket]: https://github.com/alloy/cocoapods/issues/3
[example-spec]: https://github.com/alloy/cocoapods/blob/master/examples/PodSpec.podspec
[wiki]: https://github.com/alloy/cocoapods/wiki
[license]: cocoa-pods/blob/master/LICENSE
