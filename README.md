# CocoaPods

CocoaPods is an Objective-C library dependency/package manager. It tries to take
away all hard work of maintaining your dependencies.

Its goal is to create a more centralized overview of open-source libraries and
unify the way in which we deal with them, like [RubyGems](http://rubygems.org)
does for the Ruby community.

CocoaPods will:

* Calculate the right set of versions of all of your project’s dependencies.
  _Currently the resolver is very naive and any conflicts will have to be solved
  by you, the user. This will change in the future._
* Install dependencies.
* Set them up to be build as part of a ‘dependency’ static library, which your
  project links against.

For more in depth information see the [wiki][wiki], specifically the page about
[creating a project that uses CocoaPods][wiki-create].


## Installing CocoaPods

You’ll need MacRuby. CocoaPods itself installs through RubyGems, the Ruby
package manager. Download and install [version 0.10][macruby] and then perform
the following commands:

    $ sudo macgem install cocoapods
    $ pod setup

The load time can be improved a bit by compiling the Ruby source files:

    $ sudo macgem install rubygems-compile
    $ sudo macgem compile cocoapods


## Contributing

* We need specifications for as many libraries as possible, which will help in
  adoption and finding CocoaPods issues that need to be addressed.

* There needs to be [proper documentation and guides with screenshots][wiki],
  screencasts, blog posts, etcetera.

* The project is still very young, so there's a lot still on the table. Feel
  free to create [tickets][tickets] with ideas, feedback, and issues.

* If you're looking for things to do, start by reading this
  [setup wiki page][dev-setup], then check the [tickets][tickets] and
  [the example specification][example-spec] which contains a lot of ideas we
  may, or may not, want to support.

**I will give out push access to the [cocoapods][cocoapods] and
[master spec-repo][cocoapods-specs] to anyone that has _one_) patch accepted.**


## Contact

* Follow [@CocoaPodsOrg](http://twitter.com/CocoaPodsOrg) on Twitter to stay up-to-date on new pods and general release info.
* #cocoapods on `irc.freenode.net`

Eloy Durán:

* http://github.com/alloy
* http://twitter.com/alloy
* eloy.de.enige@gmail.com


## LICENSE

These works are available under the MIT license. See the [LICENSE][license] file
for more info.


[macruby]: http://www.macruby.org/files
[cocoapods]: https://github.com/alloy/cocoapods
[cocoapods-specs]: https://github.com/alloy/cocoapods-specs
[tickets]: https://github.com/alloy/cocoapods/issues
[example-spec]: https://github.com/alloy/cocoapods/blob/master/examples/PodSpec.podspec
[dev-setup]: https://github.com/alloy/cocoapods/wiki/Setting-up-for-development-on-CocoaPods
[wiki-create]: https://github.com/alloy/cocoapods/wiki/Creating-a-project-that-uses-CocoaPods
[wiki]: https://github.com/alloy/cocoapods/wiki/_pages
[license]: cocoa-pods/blob/master/LICENSE
