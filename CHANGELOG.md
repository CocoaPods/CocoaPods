### 0.3.0

* Add support for multiple static library targets in the Pods Xcode project
  with different sets of depedencies. [[docs][targets-docs] | [example][targets-example]]

* Install libraries from anywhere. A dependency can take a git url if the repo
  contains a podspec file in its root, or a podspec can be loaded from a file
  or HTTP location. If no podspec is available, a specification can be defined
  inline in the Podfile. [[docs][spec-outside-spec-repo-docs] | [example][spec-outside-spec-repo-example]]

* Add a `post_install` hook to the Podfile class. This allows the user to
  customize, for instance, the generated Xcode project _before_ it’s written
  to disk. [[docs][post-install-docs] | [example][post-install-example]]

* Generate a Podfile.lock file next to the Podfile, which contains a manifest
  of your dependencies and its dependencies. [[example][lock-file-example]]

* Generate the Xcode projects from scratch and moved the Xcode related code out
  into its own [Xcodeproj gem][xcodeproj].



[targets-docs]: https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/podfile.rb#L151
[targets-example]: https://github.com/CocoaPods/CocoaPods/blob/master/examples/MacRubySample/Podfile
[xcodeproj]: https://github.com/CocoaPods/Xcodeproj
[spec-outside-spec-repo-docs]: https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/podfile.rb#L82
[spec-outside-spec-repo-example]: https://github.com/CocoaPods/CocoaPods/blob/master/examples/SSCatalog/Podfile
[post-install-docs]: https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/podfile.rb#L185
[post-install-example]: https://github.com/CocoaPods/CocoaPods/blob/master/examples/MacRubySample/Podfile#L17
[lock-file-example]: https://github.com/CocoaPods/CocoaPods/blob/master/examples/RKTwitter/Podfile.lock
