## 0.14.0.rc2

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.14.0.rc1...0.14.0.rc2)

###### Bug fixes

- Fix incorrect name for Pods from external sources with preferred subspecs.
- Prevent duplication of Pod with a local source and mutliple activated specs.
- Fixed the `uninitialized constant Pod::Lockfile::Digest` error.

## 0.14.0.rc1

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.13.0...0.14.0.rc1) • [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.3.1...0.3.2)

###### Enhancements

- Improve installation process by preserving the installed versions of Pods
  across installations and machines. A Pod is reinstalled if:
  - the version required in the Podfile changes and becomes incompatible with
    the installed one.
    [#191](https://github.com/CocoaPods/CocoaPods/issues/191)
  - the external source changes.
  - the head status changes (from disabled to enabled or vice-versa).

- Introduce `pod update` command that installs the dependencies of the Podfile
  **ignoring** the lockfile `Podfile.lock`.
  [#131](https://github.com/CocoaPods/CocoaPods/issues/131)

- Introduce `pod outdated` command that shows the pods with known updates.

- Add `:local` option for dependencies which will use the source files directly
  from a local directory. This is usually used for libraries that are being
  developed in parallel to the end product (application/library).
  [#458](https://github.com/CocoaPods/CocoaPods/issues/458),
  [#415](https://github.com/CocoaPods/CocoaPods/issues/415),
  [#156](https://github.com/CocoaPods/CocoaPods/issues/156).

- Folders of Pods which are no longer required are removed during installation.
  [#298](https://github.com/CocoaPods/CocoaPods/issues/298)

- Add meaningful error messages for when:
  - a podspec can’t be found in the root of an external source.
    [#385](https://github.com/CocoaPods/CocoaPods/issues/385),
    [#338](https://github.com/CocoaPods/CocoaPods/issues/338),
    [#337](https://github.com/CocoaPods/CocoaPods/issues/337).
  - a subspec name is misspelled.
    [#327](https://github.com/CocoaPods/CocoaPods/issues/327)
  - an unrecognized command and/or argument is provided.

- The subversion downloader now does an export instead of a checkout, which
  makes it play nicer with SCMs that store metadata in each directory.
  [#245](https://github.com/CocoaPods/CocoaPods/issues/245)

###### Bug fixes

- The git cache now fetches the tags from the remote if it can’t find the
  reference.
- Xcodeproj now builds on 10.6.8 and Travis CI without symlinking headers.
- Only try to install, add source files to the project, and clean a Pod once.
  [#376](https://github.com/CocoaPods/CocoaPods/issues/376)

###### Notes

- External Pods might be reinstalled due to the migration to the new
  `Podfile.lock`.
- The SCM reference of head Pods is not preserved across machines.
- Pods whose inline specification changed are not detected as modified. As a
  workaround, remove their folder stored in `Pods`.
- Pods whose specification changed are not detected as modified. As a
  workaround, remove their folder stored in `Pods`.


## 0.13.0

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.12.0...0.13.0)

###### Enhancements

- Add Podfile `podspec` which allows to use the dependencies of a podspec file.
  [#162](https://github.com/CocoaPods/CocoaPods/issues/162)
- Check if any of the build settings defined in the xcconfig files is
  overridden. [#92](https://github.com/CocoaPods/CocoaPods/issues/92)
- The Linter now checks that there are no compiler flags that disable warnings.

###### Bug fixes

- The final project isn’t affected anymore by the `inhibit_all_warnings!`
  option.
- Support for redirects while using podspec from an url.
  [#462](https://github.com/CocoaPods/CocoaPods/issues/462)


## 0.12.0

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.11.1...0.12.0)

###### Enhancements

- The documentation is generated using the public headers if they are
  specified.
- In case of a download failure the installation is aborted and the error
  message is shown.
- Git submodules are initialized only if requested.
- Don’t impose a certain structure of the user’s project by raising if no
  ‘Frameworks’ group exists.
  [#431](https://github.com/CocoaPods/CocoaPods/pull/431)
- Support for GitHub Gists in the linter.
- Allow specifying ARC settings in subspecs.
- Add Podfile `inhibit_all_warnings!` which will inhibit all warnings from the
  Pods library. [#209](https://github.com/CocoaPods/CocoaPods/issues/209)
- Make the Pods Xcode project prettier by namespacing subspecs in nested
  groups. [#466](https://github.com/CocoaPods/CocoaPods/pull/466)


## 0.11.1

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.11.0...0.11.1)

###### Bug fixes

- Fixed a crash related to subspecs without header files. [#449]
- Git submodules are loaded after the appropriate referenced is checked out and
  will be not loaded anymore in the cache. [#451]
- Fixed SVN support for the head version. [#432]


## 0.11.0

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.10.0...0.11.0)

###### Enhancements

- Added support for public headers. [#440]
- Added `pod repo lint`. [#423]
- Improved support for `:head` option and SVN repositories.
- When integrating Pods with a project without "Frameworks" group in root of
  the project, raise an informative message.
  [#431](https://github.com/CocoaPods/CocoaPods/pull/431)
- Dropped support for legacy `config.ios?` and `config.osx?`

###### Bug fixes

- Version message now correctly terminates with a 0 exit status.
- Resolved an issue that lead to git error messages in the error report.


## 0.10.0

[CocoaPods](http://git.io/4i75YA)

###### Enhancements

- Added a `--local-only` option to `pod push` so that developers can push
  locally and test before pushing to a remote. [#405](http://git.io/0ILJEw)
- Added line number information for errors generated in the Podfile.
  [#408](http://git.io/fWQvMg)
- Pods stored in git repositories now initialize submodules.
  [#406](http://git.io/L9ssSw)

###### Bug fixes

- Removed note about the post install hook form the linter.
- Improved xcodebuild error detection in the linter.
- Ensure the git cache exists, before updating it, when trying to install the
  ‘bleeding edge’ of a pod. [#426](http://git.io/d4eqRA)
- Clean downloaded external pods **after** resolving and activating (sub)specs.
  [#414](http://git.io/i77q_w)
- Support `tar.gz` as filename in a HTTP source. [#428](http://git.io/qhwKkA)


## 0.9.2

[CocoaPods](http://git.io/AVlRKg) • [Xcodeproj](http://git.io/xHbc0w)

###### Bug fixes

- When generating the PodsDummy class, make that class unique to each target. [#402](http://git.io/NntYiQ)
- Raise an informative error message when the platform in the `Podfile` is omitted or incorrect. [#403](http://git.io/k5EcUQ)


## 0.9.1

[CocoaPods](http://git.io/_kqAbw)

###### Bug fixes

- CocoaPods 0.9.x needs Xcodeproj 0.3.0.


## 0.9.0

[CocoaPods](http://git.io/kucJQw) • [Xcodeproj](http://git.io/5eLL8g)

###### Enhancements

- Force downloading the ‘bleeding edge’ version of a pod with the `:head` flag. [#392](http://git.io/t_NVRQ)
- Support for weak frameworks. [#263](http://git.io/XZDuog)
- Use double quotes when shelling out. This makes a url like `$HOME/local/lib` work. [#396](http://git.io/DnBzhA)

###### Bug fixes

- Relaxed linter to accepts pod that only specify paths to preserve (like TuneupJS).
- Gender neutralization of podfile documentation. [#384](http://git.io/MAsHXg)
- Exit early when using an old RubyGems version (< 1.4.0). These versions contain subtle bugs
  related to prerelease version comparisons. Unfortunately, OS X >= 10.7 ships with 1.3.6. [#398](http://git.io/Lr7DoA)


## 0.8.0

[CocoaPods](http://git.io/RgMF3w) • [Xcodeproj](http://git.io/KBKE_Q)

###### Breaking change

Syntax change in Podfile: `dependency` has been replaced by `pod`.

``ruby
platform :ios
pod 'JSONKit',      '~> 1.4'
pod 'Reachability', '~> 2.0.4'
``

###### Bug fixes

- Properly quote all paths given to Git.


## 0.7.0

[CocoaPods](http://git.io/Agia6A) • [Xcodeproj](http://git.io/mlqquw)

###### Features

- Added support for branches in git repos.
- Added support for linting remote files, i.e. `pod spec lint http://raw/file.podspec`.
- Improved `Spec create template`.
- The indentation is automatically stripped for podspecs strings.

###### Bug fixes

- The default warnings of Xcode are not overriden anymore.
- Improvements to the detection of the license files.
- Improvements to `pod spec lint`.
- CocoaPods is now case insensitive.


## 0.6.1

[CocoaPods](http://git.io/45wFjw) • [Xcodeproj](http://git.io/rRA4XQ)

###### Bug fixes

- Switched to master branch for specs repo.
- Fixed a crash with `pod spec lint` related to `preserve_paths`.
- Fixed a bug that caused subspecs to not inherit the compiler flags of the top level specification.
- Fixed a bug that caused duplication of system framworks.


## 0.6.0

A full list of all the changes since 0.5.1 can be found [here][6].


### Link with specific targets

CocoaPods can now integrate all the targets specified in your `Podfile`.

To specify which target, in your Xcode project, a Pods target should be linked
with, use the `link_with` method like so:

``ruby
platform :ios

workspace 'MyWorkspace'

link_with ['MyAppTarget', 'MyOtherAppTarget']
dependency 'JSONKit'

target :test, :exclusive => true do
  xcodeproj 'TestProject', 'Test' => :debug
  link_with 'TestRunnerTarget'
  dependency 'Kiwi'
end
``

_NOTE: As you can see it can take either one target name, or an array of names._

* If no explicit Xcode workspace is specified and only **one** project exists in
the same directory as the Podfile, then the name of that project is used as the
workspace’s name.

* If no explicit Xcode project is specified for a target, it will use the Xcode
project of the parent target. If no target specifies an expicit Xcode project
and there is only **one** project in the same directory as the Podfile then that
project will be used.

* If no explicit target is specified, then the Pods target will be linked with
the first target in your project. So if you only have one target you do not
need to specify the target to link with.

See [#76](https://github.com/CocoaPods/CocoaPods/issues/76) for more info.

Finally, CocoaPods will add build configurations to the Pods project for all
configurations in the other projects in the workspace. By default the
configurations are based on the `Release` configuration, to base them on the
`Debug` configuration you will have to explicitely specify them as can be seen
above in the following line:

```ruby
xcodeproj 'TestProject', 'Test' => :debug
```


### Documentation

CocoaPods will now generate documentation for every library with the
[`appledoc`][5] tool and install it into Xcode’s documentation viewer.

You can customize the settings used like so:

```ruby
s.documentation = { :appledoc => ['--product-name', 'My awesome project!'] }
```

Alternatively, you can specify a URL where an HTML version of the documentation
can be found:

```ruby
s.documentation = { :html => 'http://example.com/docs/index.html' }
```

See [#149](https://github.com/CocoaPods/CocoaPods/issues/149) and
[#151](https://github.com/CocoaPods/CocoaPods/issues/151) for more info.


### Licenses & Documentation

CocoaPods will now generate two 'Acknowledgements' files for each target specified
in your Podfile which contain the License details for each Pod used in that target
(assuming details have been specified in the Pod spec).

There is a markdown file, for general consumption, as well as a property list file
that can be added to a settings bundle for an iOS application.

You don't need to do anything for this to happen, it should just work.

If you're not happy with the default boilerplate text generated for the title, header
and footnotes in the files, it's possible to customise these by overriding the methods
that generate the text in your `Podfile` like this:

```ruby
class ::Pod::Generator::Acknowledgements
  def header_text
    "My custom header text"
  end
end
```

You can even go one step further and customise the text on a per target basis by
checking against the target name, like this:

```ruby
class ::Pod::Generator::Acknowledgements
  def header_text
    if @target_definition.label.end_with?("MyTargetName")
      "Custom header text for MyTargetName"
    else
      "Custom header text for other targets"
    end
  end
end
```

Finally, here's a list of the methods that are available to override:

```ruby
header_title
header_text
footnote_title
footnote_text
```


### Introduced two new classes: LocalPod and Sandbox.

The Sandbox represents the entire contents of the `POD_ROOT` (normally
`SOURCE_ROOT/Pods`). A LocalPod represents a pod that has been installed within
the Sandbox.

These two classes can be used as better homes for various pieces of logic
currently spread throughout the installation process and provide a better API
for working with the contents of this directory.


### Xcodeproj API

All Xcodeproj APIs are now in `snake_case`, instead of `camelCase`. If you are
manipulating the project from your Podfile's `post_install` hook, or from a
podspec, then update these method calls.


### Enhancements

* [#188](https://github.com/CocoaPods/CocoaPods/pull/188): `list` command now
  displays the specifications introduced in the master repo if it is given as an
  option the number of days to take into account.

* [#188](https://github.com/CocoaPods/CocoaPods/pull/188): Transferred search
  layout improvements and options to `list` command.

* [#166](https://github.com/CocoaPods/CocoaPods/issues/166): Added printing
  of homepage and source to search results.

* [#177](https://github.com/CocoaPods/CocoaPods/issues/177): Added `--stat`
  option to display watchers and forks for pods hosted on GitHub.

* [#177](https://github.com/CocoaPods/CocoaPods/issues/177): Introduced colors
  and tuned layout of search.

* [#112](https://github.com/CocoaPods/CocoaPods/issues/112): Introduced `--push`
  option to `$ pod setup`. It configures the master spec repository to use the private
  push URL. The change is preserved in future calls to `$ pod setup`.

* [#153](https://github.com/CocoaPods/CocoaPods/issues/153): It is no longer
  required to call `$ pod setup`.

* [#163](https://github.com/CocoaPods/CocoaPods/issues/163): Print a template
  for a new ticket when an error occurs.

* Added a new Github-specific downloader that can download repositories as a
  gzipped tarball.

* No more global state is kept during resolving of dependencies.

* Updated Xcodeproj to have a friendlier API.


### Fixes

* [#142](https://github.com/CocoaPods/CocoaPods/issues/142): Xcode 4.3.2 no longer
  supports passing the -fobj-arc flag to the linker and will fail to build. The
  addition of this flag was a workaround for a compiler bug in previous versions.
  This flag is no longer included by default - to keep using this flag, you need to
  add `set_arc_compatibility_flag!` to your Podfile.

* [#183](https://github.com/CocoaPods/CocoaPods/issues/183): Fix for
  `.DS_Store` file in `~/.cocoapods` prevents `$ pod install` from running.

* [#134](https://github.com/CocoaPods/CocoaPods/issues/134): Match
  `IPHONEOS_DEPLOYMENT_TARGET` build setting with `deployment_target` option in
  generated Pods project file.

* [#142](https://github.com/CocoaPods/CocoaPods/issues/): Add `-fobjc-arc` to
  `OTHER_LD_FLAGS` if _any_ pods require ARC.

* [#148](https://github.com/CocoaPods/CocoaPods/issues/148): External encoding
  set to UTF-8 on Ruby 1.9 to fix crash caused by non-ascii characters in pod
  description.

* Ensure all header search paths are quoted in the xcconfig file.

* Added weak quoting to `ibtool` input paths.


## 0.5.0

No longer requires MacRuby. Runs on MRI 1.8.7 (OS X system version) and 1.9.3.

A full list of all the changes since 0.3.0 can be found [here][7].


## 0.4.0

Oops, accidentally skipped this version.


## 0.3.0

### Multiple targets

Add support for multiple static library targets in the Pods Xcode project with
different sets of depedencies. This means that you can create a separate
library which contains all dependencies, including extra ones that you only use
in, for instance, a debug or test build. [[docs][1]]

```ruby
# This Podfile will build three static libraries:
# * libPods.a
# * libPods-debug.a
# * libPods-test.a

# This dependency is included in the `default` target, which generates the
# `libPods.a` library, and all non-exclusive targets.
dependency 'SSCatalog'

target :debug do
  # This dependency is only included in the `debug` target, which generates
  # the `libPods-debug.a` library.
  dependency 'CocoaLumberjack'
end

target :test, :exclusive => true do
  # This dependency is *only* included in the `test` target, which generates
  # the `libPods-test.a` library.
  dependency 'Kiwi'
end
```

### Install libraries from anywhere

A dependency can take a git url if the repo contains a podspec file in its
root, or a podspec can be loaded from a file or HTTP location. If no podspec is
available, a specification can be defined inline in the Podfile. [[docs][2]]

```ruby
# From a spec repo.
dependency 'SSToolkit'

# Directly from the Pod’s repo (if it contains a podspec).
dependency 'SSToolkit', :git => 'https://github.com/samsoffes/sstoolkit.git'

# Directly from the Pod’s repo (if it contains a podspec) with a specific commit (or tag).
dependency 'SSToolkit', :git    => 'https://github.com/samsoffes/sstoolkit.git',
                        :commit => '2adcd0f81740d6b0cd4589af98790eee3bd1ae7b'

# From a podspec that's outside a spec repo _and_ the library’s repo. This can be a file or http url.
dependency 'SSToolkit', :podspec => 'https://raw.github.com/gist/1353347/ef1800da9c5f5d267a642b8d3950b41174f2a6d7/SSToolkit-0.1.1.podspec'

# If no podspec is available anywhere, you can define one right in your Podfile.
dependency do |s|
  s.name         = 'SSToolkit'
  s.version      = '0.1.3'
  s.platform     = :ios
  s.source       = { :git => 'https://github.com/samsoffes/sstoolkit.git', :commit => '2adcd0f81740d6b0cd4589af98790eee3bd1ae7b' }
  s.resources    = 'Resources'
  s.source_files = 'SSToolkit/**/*.{h,m}'
  s.frameworks   = 'QuartzCore', 'CoreGraphics'

  def s.post_install(target)
    prefix_header = config.project_pods_root + target.prefix_header_filename
    prefix_header.open('a') do |file|
      file.puts(%{#ifdef __OBJC__\n#import "SSToolkitDefines.h"\n#endif})
    end
  end
end
```

### Add a `post_install` hook to the Podfile class

This allows the user to customize, for instance, the generated Xcode project
_before_ it’s written to disk. [[docs][3]]

```ruby
# Enable garbage collection support for MacRuby applications.
post_install do |installer|
  installer.project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['GCC_ENABLE_OBJC_GC'] = 'supported'
    end
  end
end
```

### Manifest

Generate a Podfile.lock file next to the Podfile, which contains a manifest of
your application’s dependencies and their dependencies.

```
PODS:
  - JSONKit (1.4)
  - LibComponentLogging-Core (1.1.4)
  - LibComponentLogging-NSLog (1.0.2):
    - LibComponentLogging-Core (>= 1.1.4)
  - RestKit-JSON-JSONKit (0.9.3):
    - JSONKit
    - RestKit (= 0.9.3)
  - RestKit-Network (0.9.3):
    - LibComponentLogging-NSLog
    - RestKit (= 0.9.3)
  - RestKit-ObjectMapping (0.9.3):
    - RestKit (= 0.9.3)
    - RestKit-Network (= 0.9.3)

DOWNLOAD_ONLY:
  - RestKit (0.9.3)

DEPENDENCIES:
  - RestKit-JSON-JSONKit
  - RestKit-ObjectMapping
```

### Generate Xcode projects from scratch

We no longer ship template projects with the gem, but instead generate them
programmatically. This code has moved out into its own [Xcodeproj gem][4],
allowing you to automate Xcode related tasks.




[1]: https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/podfile.rb#L151
[2]: https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/podfile.rb#L82
[3]: https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/podfile.rb#L185
[4]: https://github.com/CocoaPods/Xcodeproj
[5]: https://github.com/tomaz/appledoc
[6]: https://github.com/CocoaPods/CocoaPods/compare/0.5.1...0.6.0
[7]: https://github.com/CocoaPods/CocoaPods/compare/0.3.10...0.5.0
