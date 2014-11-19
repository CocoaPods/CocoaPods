## Installation & Update

To install or update CocoaPods see this [guide](http://docs.cocoapods.org/guides/installing_cocoapods.html).

To install release candidates run `[sudo] gem install cocoapods --pre`

## 0.35.0

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.34.4...0.35.0)
• [CocoaPods-Core](https://github.com/CocoaPods/Core/compare/0.34.4...0.35.0)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.19.4...0.20.2)
• [cocoapods-downloader](https://github.com/CocoaPods/cocoapods-downloader/compare/0.7.2...0.8.0)

##### Enhancements

* Allow the specification of file patterns for the Podspec's `requires_arc`
  attribute.  
  [Kyle Fuller](https://github.com/kylef)
  [Samuel Giddins](https://github.com/segiddins)
  [#532](https://github.com/CocoaPods/CocoaPods/issues/532)

* From now on, pods installed directly from their repositories will be recorded
  in the `Podfile.lock` file and will be guaranteed to be checked-out using the
  same revision on subsequent installations. Examples of this are when using
  the `:git`, `:svn`, or `:hg` options in your `Podfile`.  
  [Samuel Giddins](https://github.com/segiddins)
  [#1058](https://github.com/CocoaPods/CocoaPods/issues/1058)

##### Bug Fixes

* Fix an output formatting issue with various commands like `pod search`
  and `pod trunk`.
  [Olivier Halligon](https://github.com/AliSoftware)
  [#2603](https://github.com/CocoaPods/CocoaPods/issues/2603)

* Show a helpful error message if the old resolver incorrectly activated a
  pre-release version that now leads to a version conflict.  
  [Samuel Giddins](https://github.com/segiddins)

* Provides a user friendly message when using `pod spec create` with a
  repository that doesn't yet have any commits.  
  [Kyle Fuller](https://github.com/kylef)
  [#2803](https://github.com/CocoaPods/CocoaPods/issues/2803)

* Fixes an issue with integrating into projects where there is a slash in the
  build configuration name.  
  [Kyle Fuller](https://github.com/kylef)
  [#2767](https://github.com/CocoaPods/CocoaPods/issues/2767)

* Pods will use `CLANG_ENABLE_OBJC_ARC = 'YES'` instead of
  `CLANG_ENABLE_OBJC_ARC = 'NO'`. For pods with `requires_arc = false` the
  `-fno-objc-arc` flag will be specified for the all source files.  
  [Hugo Tunius](https://github.com/K0nserv)
  [#2262](https://github.com/CocoaPods/CocoaPods/issues/2262)

* Fixed an issue that Core Data mapping models where not compiled when
  copying resources to main application bundle.  
  [Yan Rabovik](https://github.com/rabovik)

##### Enhancements

* `pod search`, `pod spec which`, `pod spec cat` and `pod spec edit`
  now use plain text search by default instead of a regex. Especially
  `pod search UIView+UI` now searches for pods containing exactly `UIView+UI`
  in their name, not trying to interpret the `+` as a regular expression.
  _Note: You can still use a regular expression with the new `--regex` flag that has
  been added to these commands, e.g. `pod search --regex "(NS|UI)Color"`._
  [Olivier Halligon](https://github.com/AliSoftware)
  [Core#188](https://github.com/CocoaPods/Core/issues/188)

* Use `--allow-warnings` rather than `--error-only` for pod spec validation
  [Daniel Tomlinson](https://github.com/DanielTomlinson)
  [#2820](https://github.com/CocoaPods/CocoaPods/issues/2820)

## 0.35.0.rc2

##### Enhancements

* Allow the resolver to fail faster when there are unresolvable conflicts
  involving the Lockfile.  
  [Samuel Giddins](https://github.com/segiddins)

##### Bug Fixes

* Allows pre-release spec versions when a requirement has an external source
  specified.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2768](https://github.com/CocoaPods/CocoaPods/issues/2768)

* We no longer require git version 1.7.5 or greater.  
  [Kyle Fuller](https://github.com/kylef)

* Fix the usage of `:head` pods.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2789](https://github.com/CocoaPods/CocoaPods/issues/2789)

* Show a more informative message when attempting to lint a spec whose
  source could not be downloaded.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2667](https://github.com/CocoaPods/CocoaPods/issues/2667)
  [#2759](https://github.com/CocoaPods/CocoaPods/issues/2759)

## 0.35.0.rc1

##### Highlighted Enhancements That Need Testing

* The `Resolver` has been completely rewritten to use
  [Molinillo](https://github.com/CocoaPods/Molinillo), an iterative dependency
  resolution algorithm that automatically resolves version conflicts.
  The order in which dependencies are declared in the `Podfile` no longer has
  any effect on the resolution process.

  You should ensure that `pod install`, `pod update` and `pod update [NAME]`
  work as expected and install the correct versions of your pods during
  this RC1 release.
  [Samuel Giddins](https://github.com/segiddins)
  [#978](https://github.com/CocoaPods/CocoaPods/issues/978)
  [#2002](https://github.com/CocoaPods/CocoaPods/issues/2002)

##### Breaking

* Support for older versions of Ruby has been dropped and CocoaPods now depends
  on Ruby 2.0.0 or greater. This is due to the release of Xcode 6.0 which has
  dropped support for OS X 10.8, which results in the minimum version of
  Ruby pre-installed on OS X now being 2.0.0.

  If you are using a custom installation of Ruby  older than 2.0.0, you
  will need to update. Or even better, migrate to system Ruby.  
  [Kyle Fuller](https://github.com/kylef)

* Attempts to resolve circular dependencies will now raise an exception.  
  [Samuel Giddins](https://github.com/segiddins)
  [Molinillo#6](https://github.com/CocoaPods/Molinillo/issues/6)

##### Enhancements

* The use of implicit sources has been un-deprecated. By default, all available
  spec-repos will be used. There should only be a need to specify explicit
  sources if you want to specifically _exclude_ certain spec-repos, such as the
  `master` spec-repo, if you want to declare the order of spec look-up
  precedence, or if you want other users of a Podfile to automatically have a
  spec-repo cloned on `pod install`.  
  [Eloy Durán](https://github.com/alloy)

* The `pod push` command has been removed as it has been deprecated in favour of
  `pod repo push` in CocoaPods 0.33.  
  [Fabio Pelosin](https://github.com/fabiopelosin)

* Refactorings in preparation to framework support, which could break usage
  of the Hooks API.  
  [Marius Rackwitz](https://github.com/mrackwitz)
  [#2461](https://github.com/CocoaPods/CocoaPods/issues/2461)

* Implicit dependencies are now locked, so simply running `pod install` will not
  cause them to be updated when they shouldn't be.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2318](https://github.com/CocoaPods/CocoaPods/issues/2318)
  [#2506](https://github.com/CocoaPods/CocoaPods/issues/2506)

* Pre-release versions are only considered in the resolution process when there
  are dependencies that explicitly reference pre-release requirements.  
  [Samuel Giddins](https://github.com/segiddins)
  [#1489](https://github.com/CocoaPods/CocoaPods/issues/1489)

* Only setup the master specs repo if required.  
  [Daniel Tomlinson](https://github.com/DanielTomlinson)
  [#2562](https://github.com/CocoaPods/CocoaPods/issues/2562)

* `Sandbox::FileAccessor` now optionally includes expanded paths of headers of
  vendored frameworks in `public_headers`.  
  [Eloy Durán](https://github.com/alloy)
  [#2722](https://github.com/CocoaPods/CocoaPods/pull/2722)

* Analysis is now halted and the user informed when there are multiple different
  external sources for dependencies with the same root name.
  The user is also now warned when there are duplicate dependencies in the
  Podfile.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2738](https://github.com/CocoaPods/CocoaPods/issues/2738)

* Multiple subspecs that point to the same external dependency will now only
  cause that external source to be fetched once.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2743](https://github.com/CocoaPods/CocoaPods/issues/2743)

##### Bug Fixes

* Fixes an issue in the `XCConfigIntegrator` where not all targets that need
  integration were being integrated, but were getting incorrect warnings about
  the user having specified a custom base configuration.  
  [Eloy Durán](https://github.com/alloy)
  [2752](https://github.com/CocoaPods/CocoaPods/issues/2752)

* Do not try to clone spec-repos in `/`.  
  [Eloy Durán](https://github.com/alloy)
  [#2723](https://github.com/CocoaPods/CocoaPods/issues/2723)

* Improved sanitizing of configuration names which have a numeric prefix.  
  [Steffen Matthischke](https://github.com/HeEAaD)
  [#2700](https://github.com/CocoaPods/CocoaPods/pull/2700)

* Fixes an issues where headers from a podspec with one platform are exposed to
  targets with a different platform. The headers are now only exposed to the
  targets with the same platform.  
  [Michael Melanson](https://github.com/michaelmelanson)
  [Kyle Fuller](https://github.com/kylef)
  [#1249](https://github.com/CocoaPods/CocoaPods/issues/1249)


## 0.34.4

##### Bug Fixes

* Fixes a crash when running `pod outdated`.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2624](https://github.com/CocoaPods/CocoaPods/issues/2624)

* Ensure that external sources (as specified in the `Podfile`) are downloaded
  when their source is missing, even if their specification is present.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2494](https://github.com/CocoaPods/CocoaPods/issues/2494)

* Fixes an issue where running `pod install/update` while the Xcode project
  is open can cause the open project to have build failures until Xcode
  is restarted.  
  [Kyle Fuller](https://github.com/kylef)
  [#2627](https://github.com/CocoaPods/CocoaPods/issues/2627)
  [#2665](https://github.com/CocoaPods/CocoaPods/issues/2665)

* Fixes a crash when using file URLs as a source.  
  [Kurry Tran](https://github.com/kurry)
  [#2683](https://github.com/CocoaPods/CocoaPods/issues/2683)

* Fixes an issue when using pods in static library targets and building with
  Xcode 6 which requires `OTHER_LIBTOOLFLAGS` instead of `OTHER_LDFLAGS`, thus
  basically reverting to the previous Xcode behaviour, for now at least.  
  [Kyle Fuller](https://github.com/kylef)
  [Eloy Durán](https://github.com/alloy)
  [#2666](https://github.com/CocoaPods/CocoaPods/issues/2666)

* Fixes an issue running the resources script when Xcode is installed to a
  directory with a space when compiling xcassets.  
  [Kyle Fuller](https://github.com/kylef)
  [#2684](https://github.com/CocoaPods/CocoaPods/issues/2684)

* Fixes an issue when installing Pods with resources to a target which
  doesn't have any resources.  
  [Kyle Fuller](https://github.com/kylef)
  [#2083](https://github.com/CocoaPods/CocoaPods/issues/2083)

* Ensure that git 1.7.5 or newer is installed when running pod.  
  [Kyle Fuller](https://github.com/kylef)
  [#2651](https://github.com/CocoaPods/CocoaPods/issues/2651)


## 0.34.2

##### Enhancements

* Make the output of `pod outdated` show what running `pod update` will do.
  Takes into account the sources specified in the `Podfile`.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2470](https://github.com/CocoaPods/CocoaPods/issues/2470)

* Allows the use of the `GCC_PREPROCESSOR_DEFINITION` flag `${inherited}`
  without emitting a warning.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2577](https://github.com/CocoaPods/CocoaPods/issues/2577)

* Integration with user project will no longer replace an existing
  base build configuration.  
  [Robert Jones](https://github.com/redshirtrob)
  [#1736](https://github.com/CocoaPods/CocoaPods/issues/1736)

##### Bug Fixes

* Improved sanitizing of configuration names to avoid generating invalid
  preprocessor definitions.  
  [Boris Bügling](https://github.com/neonichu)
  [#2542](https://github.com/CocoaPods/CocoaPods/issues/2542)

* More robust generation of source names from URLs.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2534](https://github.com/CocoaPods/CocoaPods/issues/2534)

* Allow the `Validator` to only use specific sources.
  Allows customizable source for `pod spec lint` and `pod lib lint`,
  with both defaulting to `master`.
  [Samuel Giddins](https://github.com/segiddins)
  [#2543](https://github.com/CocoaPods/CocoaPods/issues/2543)
  [cocoapods-trunk#28](https://github.com/CocoaPods/cocoapods-trunk/issues/28)

* Takes into account the sources specified in `Podfile` running
  `pod outdated`.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2553](https://github.com/CocoaPods/CocoaPods/issues/2553)

* Ensures that the master repo is shallow cloned when added via a Podfile
  `source` directive.  
  [Samuel Giddins](https://github.com/segiddins)
  [#3586](https://github.com/CocoaPods/CocoaPods/issues/2586)

* Ensures that the user project is not saved when there are no
  user targets integrated.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2561](https://github.com/CocoaPods/CocoaPods/issues/2561)
  [#2593](https://github.com/CocoaPods/CocoaPods/issues/2593)

* Fix a crash when running `pod install` with an empty target that inherits a
  pod from a parent target.  
  [Kyle Fuller](https://github.com/kylef)
  [#2591](https://github.com/CocoaPods/CocoaPods/issues/2591)

* Take into account versions of a Pod from all specified sources when
  resolving dependencies.  
  [Thomas Visser](https://github.com/Thomvis)
  [#2556](https://github.com/CocoaPods/CocoaPods/issues/2556)

* Sanitize build configuration names in target environment header macros.  
  [Kra Larivain](https://github.com/olarivain)
  [#2532](https://github.com/CocoaPods/CocoaPods/pull/2532)


## 0.34.1

##### Bug Fixes

* Doesn't take into account the trailing `.git` in repository URLs when
  trying to find a matching specs repo.  
  [Samuel Giddins](https://github.com/segiddins)
  [#2526](https://github.com/CocoaPods/CocoaPods/issues/2526)


## 0.34.0

##### Breaking

* Add support for loading podspecs from *only* specific spec-repos via
  `sources`. By default, when there are no sources specified in a Podfile all
  source repos will be used. This has always been the case. However, this
  implicit use of sources is now deprecated. Once you specify specific sources,
  **no** repos will be included by default. For example:

        source 'https://github.com/artsy/Specs.git'
        source 'https://github.com/CocoaPods/Specs.git'

  Any source URLs specified that have not yet been added will be cloned before
  resolution begins.  
  [François Benaiteau](https://github.com/netbe)
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [Samuel Giddins](https://github.com/segiddins)
  [#1143](https://github.com/CocoaPods/CocoaPods/pull/1143)
  [Core#19](https://github.com/CocoaPods/Core/pull/19)
  [Core#170](https://github.com/CocoaPods/Core/issues/170)
  [#2515](https://github.com/CocoaPods/CocoaPods/issues/2515)

##### Enhancements

* Added the `pod repo list` command which lists all the repositories.  
  [Luis Ascorbe](https://github.com/lascorbe)
  [#1455](https://github.com/CocoaPods/CocoaPods/issues/1455)

##### Bug Fixes

* Works around an Xcode issue where linting would fail even though `xcodebuild`
  actually succeeds. Xcode.app also doesn't fail when this issue occurs, so it's
  safe for us to do the same.  
  [Kra Larivain](https://github.com/olarivain)
  [Boris Bügling](https://github.com/neonichu)
  [Eloy Durán](https://github.com/alloy)
  [Samuel E. Giddins](https://github.com/segiddins)
  [#2394](https://github.com/CocoaPods/CocoaPods/issues/2394)
  [#2395](https://github.com/CocoaPods/CocoaPods/pull/2395)

* Fixes the detection of JSON podspecs included via `:path`.  
  [laiso](https://github.com/laiso)
  [#2489](https://github.com/CocoaPods/CocoaPods/pull/2489)

* Fixes an issue where `pod install` would crash during Plist building if any
  pod has invalid UTF-8 characters in their title or description.  
  [Ladislav Martincik](https://github.com/martincik)
  [#2482](https://github.com/CocoaPods/CocoaPods/issues/2482)

* Fix crash when the URL of a private GitHub repo is passed to `pod spec
  create` as an argument.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1543](https://github.com/CocoaPods/CocoaPods/issues/1543)


## 0.34.0.rc2

##### Bug Fixes

* Fixes an issue where `pod lib lint` would crash if a podspec couldn't be
  loaded.  
  [Kyle Fuller](https://github.com/kylef)
  [#2147](https://github.com/CocoaPods/CocoaPods/issues/2147)

* Fixes an issue where `pod init` would not add `source 'master'` to newly
  created Podfiles.  
  [Ash Furrow](https://github.com/AshFurrow)
  [#2473](https://github.com/CocoaPods/CocoaPods/issues/2473)


## 0.34.0.rc1

##### Breaking

* The use of the `$PODS_ROOT` environment variable has been deprecated and
  should not be used. It will be removed in future versions of CocoaPods.  
  [#2449](https://github.com/CocoaPods/CocoaPods/issues/2449)

* Add support for loading podspecs from specific spec-repos _only_, a.k.a. ‘sources’.
  By default, when not specifying any specific sources in your Podfile, the ‘master’
  spec-repo will be used, as was always the case. However, once you specify specific
  sources the ‘master’ spec-repo will **not** be included by default. For example:

        source 'private-spec-repo'
        source 'master'

  [François Benaiteau](https://github.com/netbe)
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1143](https://github.com/CocoaPods/CocoaPods/pull/1143)
  [Core#19](https://github.com/CocoaPods/Core/pull/19)

* The `Pods` directory has been reorganized. This might require manual
  intervention in projects where files generated by CocoaPods have manually been
  imported into the user's project (common with the acknowledgements files).  
  [#1055](https://github.com/CocoaPods/CocoaPods/pull/1055)
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [Michele Titolo](https://github.com/mtitolo)

* Plugins are now expected to include the `cocoapods-plugin.rb` file in
  `./lib`.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [CLAide#28](https://github.com/CocoaPods/CLAide/pull/28)

* The specification `requires_arc` attribute now defaults to true.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [CocoaPods#267](https://github.com/CocoaPods/CocoaPods/issues/267)

##### Enhancements

* Add support to specify dependencies per build configuration:

        pod 'Lookback', :configurations => ['Debug']

  Currently configurations can only be specified per single Pod.  
  [Joachim Bengtsson](https://github.com/nevyn)
  [Eloy Durán](https://github.com/alloy)
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1791](https://github.com/CocoaPods/CocoaPods/pull/1791)
  [#1668](https://github.com/CocoaPods/CocoaPods/pull/1668)
  [#731](https://github.com/CocoaPods/CocoaPods/pull/731)

* Improved performance of git downloads using shallow clone.  
  [Marin Usalj](https://github.com/supermarin)
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [cocoapods-downloader#29](https://github.com/CocoaPods/cocoapods-downloader/pull/29)

* Simplify installation: CocoaPods no longer requires the
  compilation of the troublesome native extensions.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [Xcodeproj#168](https://github.com/CocoaPods/Xcodeproj/pull/168)
  [Xcodeproj#167](https://github.com/CocoaPods/Xcodeproj/issues/167)

* Add hooks for plugins. Currently only the installer hook is supported.
  A plugin can register itself to be activated after the installation with the
  following syntax:

      Pod::HooksManager.register(:post_install) do |installer_context|
        # implementation
      end

  The `installer_context` is an instance of the `Pod::Installer:HooksContext`
  class which provides the information about the installation.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [Core#132](https://github.com/CocoaPods/Core/pull/1755)

* Add a support for migrating the sandbox to new versions of CocoaPods.  
  [Fabio Pelosin](https://github.com/fabiopelosin)

* Display an indication for deprecated Pods in the command line search.  
  [Hugo Tunius](https://github.com/k0nserv)
  [#2180](https://github.com/CocoaPods/CocoaPods/issues/2180)

* Use the CLIntegracon gem for the integration tests.  
  [Marius Rackwitz](https://github.com/mrackwitz)
  [#2371](https://github.com/CocoaPods/CocoaPods/issues/2371)

* Include configurations that a user explicitly specifies, in their Podfile,
  when the `--no-integrate` option is specified.  
  [Eloy Durán](https://github.com/alloy)

* Properly quote the `-isystem` values in the xcconfig files.  
  [Eloy Durán](https://github.com/alloy)

* Remove the installation post install message which presents the CHANGELOG.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [Eloy Durán](https://github.com/alloy)

* Add support for user-specified project directories with the
  `--project-directory` option.  
  [Samuel E. Giddins](https://github.com/segiddins)
  [#2183](https://github.com/CocoaPods/CocoaPods/issues/2183)

* Now the `plutil` tool is used when available to produce
  output consistent with Xcode.  
  [Fabio Pelosin](https://github.com/fabiopelosin)

* Indicate the name of the pod whose requirements cannot be satisfied.  
  [Seivan Heidari](https://github.com/seivan)
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1938](https://github.com/CocoaPods/CocoaPods/issues/1938)

* Add support for JSON specs to external sources (`:path`, `:git`, etc)
  options.  
  [Kyle Fuller](https://github.com/kylef)
  [#2320](https://github.com/CocoaPods/CocoaPods/issues/2320)

* Generate the workspaces using the same output of Xcode.  
  [Fabio Pelosin](https://github.com/fabiopelosin)


##### Bug Fixes

* Fix `pod repo push` to first check if a Specs directory exists and if so
  push there.  
  [Edward Valentini](edwardvalentini)
  [#2060](https://github.com/CocoaPods/CocoaPods/issues/2060)

* Fix `pod outdated` to not include subspecs.  
  [Ash Furrow](ashfurrow)
  [#2136](https://github.com/CocoaPods/CocoaPods/issues/2136)

* Always evaluate podspecs from the original podspec directory. This fixes
  an issue when depending on a pod via `:path` and that pod's podspec uses
  relative paths.  
  [Kyle Fuller](kylef)
  [pod-template#50](https://github.com/CocoaPods/pod-template/issues/50)

* Fix spec linting to not warn for missing license file in subspecs.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [Core#132](https://github.com/CocoaPods/Core/issues/132)

* Fix `pod init` so that it doesn't recurse when checking for Podfiles.  
  [Paddy O'Brien](https://github.com/tapi)
  [#2181](https://github.com/CocoaPods/CocoaPods/issues/2181)

* Fix missing XCTest framework in Xcode 6.  
  [Paul Williamson](squarefrog)
  [#2296](https://github.com/CocoaPods/CocoaPods/issues/2296)

* Support multiple values in `ARCHS`.  
  [Robert Zuber](https://github.com/z00b)
  [#1904](https://github.com/CocoaPods/CocoaPods/issues/1904)

* Fix static analysis in Xcode 6.  
  [Samuel E. Giddins](https://github.com/segiddins)
  [#2402](https://github.com/CocoaPods/CocoaPods/issues/2402)

* Fix an issue where a version of a spec will not be locked when using
  multiple subspecs of a podspec.  
  [Kyle Fuller](https://github.com/kylef)
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#2135](https://github.com/CocoaPods/CocoaPods/issues/2135)

* Fix an issue using JSON podspecs installed directly from a lib's
  repository.  
  [Kyle Fuller](https://github.com/kylef)
  [#2320](https://github.com/CocoaPods/CocoaPods/issues/2320)

* Support and use quotes in the `OTHER_LDFLAGS` of xcconfigs to avoid
  issues with targets containing a space character in their name.  
  [Fabio Pelosin](https://github.com/fabiopelosin)


## 0.33.1

##### Bug Fixes

* Fix `pod spec lint` for `json` podspecs.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#2157](https://github.com/CocoaPods/CocoaPods/issues/2157)

* Fixed downloader issues related to `json` podspecs.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#2158](https://github.com/CocoaPods/CocoaPods/issues/2158)

* Fixed `--no-ansi` flag in help banners.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#34](https://github.com/CocoaPods/CLAide/issues/34)


## 0.33.0

##### Breaking

* The deprecated `pre_install` and the `pod_install` hooks of the specification
  class have been removed.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#2151](https://github.com/CocoaPods/CocoaPods/issues/2151)
  [#2153](https://github.com/CocoaPods/CocoaPods/pull/2153)

##### Enhancements

* Added the `cocoapods-trunk` plugin which introduces the `trunk` subcommand.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#2151](https://github.com/CocoaPods/CocoaPods/issues/2151)
  [#2153](https://github.com/CocoaPods/CocoaPods/pull/2153)

* The `pod push` sub-command has been moved to the `pod repo push` sub-command.
  Moreover pushing to the master repo from it has been disabled.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#2151](https://github.com/CocoaPods/CocoaPods/issues/2151)
  [#2153](https://github.com/CocoaPods/CocoaPods/pull/2153)

* Overhauled command line interface. Add support for auto-completion script
  (d). If auto-completion is enabled for your shell you can configure it for
  CocoaPods with the following command:

      rm -f /usr/local/share/zsh/site-functions/_pod
      dpod --completion-script > /usr/local/share/zsh/site-functions/_pod
      exec zsh

  Currently only the Z shell is supported.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [CLAide#25](https://github.com/CocoaPods/CLAide/issues/25)
  [CLAide#20](https://github.com/CocoaPods/CLAide/issues/20)
  [CLAide#19](https://github.com/CocoaPods/CLAide/issues/19)
  [CLAide#17](https://github.com/CocoaPods/CLAide/issues/17)
  [CLAide#12](https://github.com/CocoaPods/CLAide/issues/12)

* The `--version` flag is now only supported for the root `pod` command. If
  used in conjunction with the `--verbose` flag the version of the detected
  plugins will be printed as well.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [CLAide#13](https://github.com/CocoaPods/CLAide/issues/13)
  [CLAide#14](https://github.com/CocoaPods/CLAide/issues/14)

* The extremely meta `cocoaPods-plugins` is now installed by default providing
  information about the available and the installed plug-ins.  
  [David Grandinetti](https://github.com/dbgrandi)
  [Olivier Halligon](https://github.com/AliSoftware)
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#2092](https://github.com/CocoaPods/CocoaPods/issues/2092)

* Validate the reachability of `social_media_url`, `documentation_url` and
  `docset_url` in podspecs we while linting a specification.  
  [Kyle Fuller](https://github.com/kylef)
  [#2025](https://github.com/CocoaPods/CocoaPods/issues/2025)

* Print the current version when the repo/lockfile requires a higher version.  
  [Samuel E. Giddins](https://github.com/segiddins)
  [#2049](https://github.com/CocoaPods/CocoaPods/issues/2049)

* Show `help` when running the `pod` command instead of defaulting to `pod
  install`.  
  [Kyle Fuller](https://github.com/kylef)
  [#1771](https://github.com/CocoaPods/CocoaPods/issues/1771)

##### Bug Fixes

* Show the actual executable when external commands fail.  
  [Boris Bügling](https://github.com/neonichu)
  [#2102](https://github.com/CocoaPods/CocoaPods/issues/2102)

* Fixed support for file references in the workspace generated by CocoaPods.  
  [Kyle Fuller](https://github.com/kylef)
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [Xcodeproj#105](https://github.com/CocoaPods/Xcodeproj/pull/150)

* Show a helpful error message when reading version information with merge
  conflict.  
  [Samuel E. Giddins](https://github.com/segiddins)
  [#1853](https://github.com/CocoaPods/CocoaPods/issues/1853)

* Show deprecated specs when invoking `pod outdated`.  
  [Samuel E. Giddins](https://github.com/segiddins)
  [#2003](https://github.com/CocoaPods/CocoaPods/issues/2003)

* Fixes an issue where `pod repo update` may start an un-committed merge.  
  [Kyle Fuller](https://github.com/kylef)
  [#2024](https://github.com/CocoaPods/CocoaPods/issues/2024)

## 0.32.1

##### Bug Fixes

* Fixed the Podfile `default_subspec` attribute in nested subspecs.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#2050](https://github.com/CocoaPods/CocoaPods/issues/2050)

## 0.32.0

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/master...0.31.1)
• [CocoaPods-Core](https://github.com/CocoaPods/Core/compare/master...0.31.1)

##### Enhancements

* Allow to update only a list of given pods with `pod update [POD_NAMES...]`.  
  [Marius Rackwitz](https://github.com/mrackwitz)
  [CocoaPods#760](https://github.com/CocoaPods/CocoaPods/issues/760)

* `pod update` prints the previous version of the updated pods.  
  [Andrea Mazzini](https://github.com/andreamazz)
  [#2008](https://github.com/CocoaPods/CocoaPods/issues/2008)

* `pod update` falls back to `pod install` if no Lockfile is present.  
  [Marius Rackwitz](https://github.com/mrackwitz)

* File references in the Pods project for development Pods now are absolute if
  the dependency is specified with an absolute paths.  
  [Samuel Ford](https://github.com/samuelwford)
  [#1042](https://github.com/CocoaPods/CocoaPods/issues/1042)

* Added `deprecated` and `deprecated_in_favor_of` attributes to Specification
  DSL.  
  [Paul Young](https://github.com/paulyoung)
  [Core#87](https://github.com/CocoaPods/Core/pull/87)

* Numerous improvements to the validator and to the linter.
  * Validate the reachability of screenshot URLs in podspecs while linting a
    specification.  
    [Kyle Fuller](https://github.com/kylef)
    [#2010](https://github.com/CocoaPods/CocoaPods/issues/2010)
  * Support HTTP redirects when linting homepage and screenshots.  
    [Boris Bügling](https://github.com/neonichu)
    [#2027](https://github.com/CocoaPods/CocoaPods/pull/2027)
  * The linter now checks `framework` and `library` attributes for invalid
    strings.  
    [Paul Williamson](https://github.com/squarefrog)
    [Fabio Pelosin](fabiopelosin)
    [Core#66](https://github.com/CocoaPods/Core/issues/66)
    [Core#96](https://github.com/CocoaPods/Core/pull/96)
    [Core#105](https://github.com/CocoaPods/Core/issues/105)
  * The Linter will not check for comments anymore.  
    [Fabio Pelosin](https://github.com/fabiopelosin)
    [Core#108](https://github.com/CocoaPods/Core/issues/108)
  * Removed legacy checks from the linter.  
    [Fabio Pelosin](https://github.com/fabiopelosin)
    [Core#108](https://github.com/CocoaPods/Core/issues/108)
  * Added logic to handle subspecs and platform scopes to linter check of
    the `requries_arc` attribute.  
    [Fabio Pelosin](https://github.com/fabiopelosin)
    [CocoaPods#2005](https://github.com/CocoaPods/CocoaPods/issues/2005)
  * The linter no longer considers empty a Specification if it only specifies the
    `resource_bundle` attribute.  
    [Joshua Kalpin](https://github.com/Kapin)
    [#63](https://github.com/CocoaPods/Core/issues/63)
    [#95](https://github.com/CocoaPods/Core/pull/95)

* `pod lib create` is now using the `configure` file instead of the
  `_CONFIGURE.rb` file.  
  [Piet Brauer](https://github.com/pietbrauer)
  [Orta Therox](https://github.com/orta)

* `pod lib create` now disallows any pod name that begins with a `.`  
  [Dustin Clark](https://github.com/clarkda)
  [#2026](https://github.com/CocoaPods/CocoaPods/pull/2026)
  [Core#97](https://github.com/CocoaPods/Core/pull/97)
  [Core#98](https://github.com/CocoaPods/Core/issues/98)

* Prevent the user from using `pod` commands as root.  
  [Kyle Fuller](https://github.com/kylef)
  [#1815](https://github.com/CocoaPods/CocoaPods/issues/1815)

* Dependencies declared with external sources now support HTTP downloads and
  have improved support for all the options supported by the downloader.  
  [Fabio Pelosin](https://github.com/fabiopelosin)

* An informative error message is presented when merge conflict is detected in
  a YAML file.  
  [Luis de la Rosa](https://github.com/luisdelarosa)
  [#69](https://github.com/CocoaPods/Core/issues/69)
  [#100](https://github.com/CocoaPods/Core/pull/100)

##### Bug Fixes

* Fixed the Podfile `default_subspec` attribute in nested subspecs.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1021](https://github.com/CocoaPods/CocoaPods/issues/1021)

* Warn when including deprecated pods
  [Samuel E. Giddins](https://github.com/segiddins)
  [#2003](https://github.com/CocoaPods/CocoaPods/issues/2003)


## 0.31.1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.31.1...0.31.0)
• [CocoaPods-Core](https://github.com/CocoaPods/Core/compare/0.31.1...0.31.0)

##### Minor Enhancements

* The specification now strips the indentation of the `prefix_header` and
  `prepare_command` to aide their declaration as a here document (similarly to
  what it already does with the description).  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [Core#51](https://github.com/CocoaPods/Core/issues/51)

##### Bug Fixes

* Fix linting for Pods which declare a private repo as the source.  
  [Boris Bügling](https://github.com/neonichu)
  [Core#82](https://github.com/CocoaPods/Core/issues/82)


## 0.31.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.30.0...0.31.0)
• [CocoaPods-Core](https://github.com/CocoaPods/Core/compare/0.30.0...0.31.0)

##### Enhancements

* Warnings are not promoted to errors anymore to maximise compatibility with
  existing libraries.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1629](https://github.com/CocoaPods/CocoaPods/issues/1629)

* Include the versions of the Pods to the output of `pod list`.  
  [Stefan Damm](https://github.com/StefanDamm)
  [Robert Zuber](https://github.com/z00b)
  [#1617](https://github.com/CocoaPods/CocoaPods/issues/1617)

* Generated prefix header file will now have unique prefix_header_contents for
  Pods with subspecs.  
  [Luis de la Rosa](https://github.com/luisdelarosa)
  [#1449](https://github.com/CocoaPods/CocoaPods/issues/1449)

* The linter will now check the reachability of the homepage of Podspecs during
  a full lint.  
  [Richard Lee](https://github.com/dlackty)
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1704](https://github.com/CocoaPods/CocoaPods/issues/1704)
  [Core#70](https://github.com/CocoaPods/Core/pull/70)

* Improved detection of the last version of a specification in `pod spec`
  subcommands.  
  [Laurent Sansonetti](https://github.com/lrz)
  [#1953](https://github.com/CocoaPods/CocoaPods/pull/1953)

* Display advised settings for Travis CI in the warning related presented when
  the terminal encoding is not set to UTF-8.  
  [Richard Lee](https://github.com/dlackty)
  [#1933](https://github.com/CocoaPods/CocoaPods/issues/1933)
  [#1941](https://github.com/CocoaPods/CocoaPods/pull/1941)

* Unset the `CDPATH` env variable before shelling-out to `prepare_command`.  
  [Marc Boquet](https://github.com/apalancat)
  [#1943](https://github.com/CocoaPods/CocoaPods/pull/1943)

##### Bug Fixes

* Resolve crash related to the I18n deprecation warning.  
  [Eloy Durán](https://github.com/alloy)
  [#1950](https://github.com/CocoaPods/CocoaPods/issues/1950)

* Fix compilation issues related to the native Extension of Xcodeproj.  
  [Eloy Durán](https://github.com/alloy)

* Robustness against user Git configuration and against merge commits in `pod
  repo` subcommands.  
  [Boris Bügling](https://github.com/neonichu)
  [#1949](https://github.com/CocoaPods/CocoaPods/issues/1949)
  [#1978](https://github.com/CocoaPods/CocoaPods/pull/1978)

* Gracefully inform the user if the `:head` option is not supported for a given
  download strategy.  
  [Boris Bügling](https://github.com/neonichu)
  [#1947](https://github.com/CocoaPods/CocoaPods/issues/1947)
  [#1958](https://github.com/CocoaPods/CocoaPods/pull/1958)

* Cleanup a pod directory if error occurs while downloading.  
  [Alex Rothenberg](https://github.com/alexrothenberg)
  [#1842](https://github.com/CocoaPods/CocoaPods/issues/1842)
  [#1960](https://github.com/CocoaPods/CocoaPods/pull/1960)

* No longer warn for Github repositories with OAuth authentication.  
  [Boris Bügling](https://github.com/neonichu)
  [#1928](https://github.com/CocoaPods/CocoaPods/issues/1928)
  [Core#77](https://github.com/CocoaPods/Core/pull/77)

* Fix for when using `s.version` as the `:tag` for a git repository in a
  Podspec.  
  [Joel Parsons](https://github.com/joelparsons)
  [#1721](https://github.com/CocoaPods/CocoaPods/issues/1721)
  [Core#72](https://github.com/CocoaPods/Core/pull/72)

* Improved escaping of paths in Git downloader.  
  [Vladimir Burdukov](https://github.com/chipp)
  [cocoapods-downloader#14](https://github.com/CocoaPods/cocoapods-downloader/pull/14)

* Podspec without explicitly set `requires_arc` attribute no longer passes the
  lint.  
  [Richard Lee](https://github.com/dlackty)
  [#1840](https://github.com/CocoaPods/CocoaPods/issues/1840)
  [Core#71](https://github.com/CocoaPods/Core/pull/71)

* Properly quote headers in the `-isystem` compiler flag of the aggregate
  targets.  
  [Eloy Durán](https://github.com/alloy)
  [#1862](https://github.com/CocoaPods/CocoaPods/issues/1862)
  [#1894](https://github.com/CocoaPods/CocoaPods/pull/1894)

## 0.30.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.29.0...0.30.0)

###### Enhancements

* Radically reduce first run pod setup bandwidth by creating a shallow clone of
  the ‘master’ repo by default. Use the `--no-shallow` option to perform a full
  clone instead.  
  [Jeff Verkoeyen](https://github.com/jverkoey)
  [#1803](https://github.com/CocoaPods/CocoaPods/pull/1803)

* Improves the error message when searching with an invalid regular expression.  
  [Kyle Fuller](https://github.com/kylef)

* Improves `pod init` to save Xcode project file in Podfile when one was supplied.  
  [Kyle Fuller](https://github.com/kylef)

* Adds functionality to specify a template URL for the `pod lib create` command.  
  [Piet Brauer](https://github.com/pietbrauer)

###### Bug Fixes

* Fixes a bug with `pod repo remove` silently handling permission errors.  
  [Kyle Fuller](https://github.com/kylef)
  [#1778](https://github.com/CocoaPods/CocoaPods/issues/1778)

* `pod push` now properly checks that the repo has changed before attempting
  to commit. This only affected pods with special characters (such as `+`) in
  their names.  
  [Gordon Fontenot](https://github.com/gfontenot)
  [#1739](https://github.com/CocoaPods/CocoaPods/pull/1739)


## 0.29.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.28.0...0.29.0)
• [CocoaPods-core](https://github.com/CocoaPods/Core/compare/0.28.0...0.29.0)
• [cocoapods-downloader](https://github.com/CocoaPods/cocoapods-downloader/compare/0.2.0...0.3.0)

###### Breaking

* The command `podfile_info` is now a plugin offered by CocoaPods.
  As a result, the command has been removed from CocoaPods.  
  [Joshua Kalpin](https://github.com/Kapin)
  [#1589](https://github.com/CocoaPods/CocoaPods/issues/1589)

* JSON has been adopted as the format to store specifications. As a result
  the `pod ipc spec` command returns a JSON representation and the YAML
  specifications are not supported anymore. JSON specifications adopt the
  `.podspec.json` extension.
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1568](https://github.com/CocoaPods/CocoaPods/pull/1568)

###### Enhancements

* Introduced `pod try` the easiest way to test the example project of a pod.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1568](https://github.com/CocoaPods/CocoaPods/pull/1568)

* Pod headers are now provided to the user target as a system
  header. This means that any warnings in a Pod's code will show
  under its target in Xcode's build navigator, and never under the
  user target.  
  [Swizzlr](https://github.com/swizzlr)
  [#1596](https://github.com/CocoaPods/CocoaPods/pull/1596)

* Support LZMA2 compressed tarballs in the downloader.  
  [Kyle Fuller](https://github.com/kylef)
  [cocoapods-downloader#5](https://github.com/CocoaPods/cocoapods-downloader/pull/5)

* Add Bazaar support for installing directly from a repo.  
  [Fred McCann](https://github.com/fmccann)
  [#1632](https://github.com/CocoaPods/CocoaPods/pull/1632)

* The `pod search <query>` command now supports regular expressions
  for the query parameter when searching using the option `--full`.  
  [Florian Hanke](https://github.com/floere)
  [#1643](https://github.com/CocoaPods/CocoaPods/pull/1643)

* Pod lib lint now accepts multiple podspecs in the same folder.  
  [kra Larivain/OpenTable](https://github.com/opentable)
  [#1635](https://github.com/CocoaPods/CocoaPods/pull/1635)

* The `pod push` command will now silently test the upcoming CocoaPods trunk
  service. The service is only tested when pushing to the master repo and the
  test doesn't affect the normal workflow.  
  [Fabio Pelosin](https://github.com/fabiopelosin)

* The `pod search <query>` command now supports searching on cocoapods.org
  when searching using the option `--web`. Options `--ios` and `--osx` are
  fully supported.
  [Florian Hanke](https://github.com/floere)
  [#1643](https://github.com/CocoaPods/CocoaPods/pull/1682)

* The `pod search <query>` command now supports multiword queries when using
  the `--web` option.
  [Florian Hanke](https://github.com/floere)
  [#1643](https://github.com/CocoaPods/CocoaPods/pull/1682)

###### Bug Fixes

* Fixed a bug which resulted in `pod lib lint` not being able to find the
  headers.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1566](https://github.com/CocoaPods/CocoaPods/issues/1566)

* Fixed the developer frameworks search paths so that
  `$(SDKROOT)/Developer/Library/Frameworks` is used for iOS and
  `$(DEVELOPER_LIBRARY_DIR)/Frameworks` is used for OS X.  
  [Kevin Wales](https://github.com/kwales)
  [#1562](https://github.com/CocoaPods/CocoaPods/pull/1562)

* When updating the pod repos, repositories with unreachable remotes
  are now ignored. This fixes an issue with certain private repositories.  
  [Joshua Kalpin](https://github.com/Kapin)
  [#1595](https://github.com/CocoaPods/CocoaPods/pull/1595)
  [#1571](https://github.com/CocoaPods/CocoaPods/issues/1571)

* The linter will now display an error if a Pod's name contains whitespace.  
  [Joshua Kalpin](https://github.com/Kapin)
  [Core#39](https://github.com/CocoaPods/Core/pull/39)
  [#1610](https://github.com/CocoaPods/CocoaPods/issues/1610)

* Having the silent flag enabled in the config will no longer cause issues
  with `pod search`. In addition, the flag `--silent` is no longer supported
  for the command.  
  [Joshua Kalpin](https://github.com/Kapin)
  [#1627](https://github.com/CocoaPods/CocoaPods/pull/1627)

* The linter will now display an error if a framework ends with `.framework`
  (i.e. `QuartzCore.framework`).  
  [Joshua Kalpin](https://github.com/Kapin)
  [#1331](https://github.com/CocoaPods/CocoaPods/issues/1336)
  [Core#45](https://github.com/CocoaPods/Core/pull/45)

* The linter will now display an error if a library ends with `.a` or `.dylib`
  (i.e. `z.dylib`). It will also display an error if it begins with `lib`
  (i.e. `libxml`).  
  [Joshua Kalpin](https://github.com/Kapin)
  [Core#44](https://github.com/CocoaPods/Core/issues/44)

* The ARCHS build setting can come back as an array when more than one
  architecture is specified.  
  [Carson McDonald](https://github.com/carsonmcdonald)
  [#1628](https://github.com/CocoaPods/CocoaPods/issues/1628)

* Fixed all issues caused by `/tmp` being a symlink to `/private/tmp`.
  This affected mostly `pod lib lint`, causing it to fail when the
  Pod used `prefix_header_*` or when the pod headers imported headers
  using the namespaced syntax (e.g. `#import <MyPod/Header.h>`).  
  [kra Larivain/OpenTable](https://github.com/opentable)
  [#1514](https://github.com/CocoaPods/CocoaPods/pull/1514)

* Fixed an incorrect path being used in the example app Podfile generated by
  `pod lib create`.
  [Eloy Durán](https://github.com/alloy)
  [cocoapods-try#5](https://github.com/CocoaPods/cocoapods-try/issues/5)


## 0.28.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.27.1...0.28.0)
• [CocoaPods-core](https://github.com/CocoaPods/Core/compare/0.27.1...0.28.0)
• [CLAide](https://github.com/CocoaPods/CLAide/compare/0.3.2...0.4.0)

###### Enhancements

* CLAide now supports gem plugins. An example CocoaPods plugin can be found at
  [open\_pod\_bay](https://github.com/leshill/open_pod_bay).

  As of yet there are no promises made yet on the APIs, so try to fail as
  gracefully as possible in case a CocoaPods update breaks your usage. In these
  cases, also please let us know what you would need, so we can take this into
  account when we do finalize APIs.

  [Les Hill](https://github.com/leshill)
  [CLAide#1](https://github.com/CocoaPods/CLAide/pull/1)
  [#959](https://github.com/CocoaPods/CocoaPods/issues/959)

###### Bug Fixes

* Compiling `xcassets` with `actool` now uses `UNLOCALIZED_RESOURCES_FOLDER_PATH`
  instead of `PRODUCT_NAME.WRAPPER_EXTENSION` as output directory as it is more
  accurate and allows the project to overwrite `WRAPPER_NAME`.  
  [Marc Knaup](https://github.com/fluidsonic)
  [#1556](https://github.com/CocoaPods/CocoaPods/pull/1556)

* Added a condition to avoid compiling xcassets when `WRAPPER_EXTENSION`
  is undefined, as it would be in the case of static libraries. This prevents
  trying to copy the compiled files to a directory that does not exist.  
  [Noah McCann](https://github.com/nmccann)
  [#1521](https://github.com/CocoaPods/CocoaPods/pull/1521)

* Added additional condition to check if `actool` is available when compiling
  `xcassets`. This prevents build failures of Xcode 5 projects on Travis CI (or
  lower Xcode versions).  
  [Michal Konturek](https://github.com/michalkonturek)
  [#1511](https://github.com/CocoaPods/CocoaPods/pull/1511)

* Added a condition to properly handle universal or mac apps when compiling
  xcassets. This prevents build errors in the xcassets compilation stage
  particularly when using xctool to build.  
  [Ryan Marsh](https://github.com/ryanwmarsh)
  [#1594](https://github.com/CocoaPods/CocoaPods/pull/1594)

* Vendored Libraries now correctly affect whether a podspec is considered empty.  
  [Joshua Kalpin](https://github.com/Kapin)
  [Core#38](https://github.com/CocoaPods/Core/pull/38)

* Vendored Libraries and Vendored Frameworks now have their paths validated correctly.  
  [Joshua Kalpin](https://github.com/Kapin)
  [#1567](https://github.com/CocoaPods/CocoaPods/pull/1567)

* Gists are now correctly accepted with https.  
  [Joshua Kalpin](https://github.com/Kapin)
  [Core#38](https://github.com/CocoaPods/Core/pull/38)

* The `pod push` command is now more specific about the branch it pushes to.  
  [orta](http://orta.github.io)
  [#1561](https://github.com/CocoaPods/CocoaPods/pull/1561)

* Dtrace files are now properly left unflagged when installing, regardless of configuration.  
  [Swizzlr](https://github.com/swizzlr)
  [#1560](https://github.com/CocoaPods/CocoaPods/pull/1560)

* Users are now warned if their terminal encoding is not UTF-8. This fixes an issue
  with a small percentage of pod names that are incompatible with ASCII.  
  [Joshua Kalpin](https://github.com/Kapin)
  [#1570](https://github.com/CocoaPods/CocoaPods/pull/1570)


## 0.27.1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.26.2...0.27.1)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.26.2...0.27.1)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.13.0...0.14.0)

###### Enhancements

* The xcodeproj gem now comes bundled with prebuilt binaries for the Ruby
  versions that come with OS X 10.8 and 10.9. Users now no longer need to
  install the Xcode Command Line Tools or deal with the Ruby C header location.  
  [Eloy Durán](https://github.com/alloy)
  [Xcodeproj#88](https://github.com/CocoaPods/Xcodeproj/issues/88)

* Targets passed to the `link_with` method of the Podfile DSL no longer need
  to be explicitly passed as an array. `link_with ['target1', 'target2']` can
  now be written as `link_with 'target1', 'target2'`.  
  [Adam Sharp](https://github.com/sharplet)
  [Core#30](https://github.com/CocoaPods/Core/pull/30)

* The copy resources script now compiles xcassets resources.  
  [Ulrik Damm](https://github.com/ulrikdamm)
  [#1427](https://github.com/CocoaPods/CocoaPods/pull/1427)

* `pod repo` now support a `remove ['repo_name']` command.  
  [Joshua Kalpin](https://github.com/Kapin)
  [#1493](https://github.com/CocoaPods/CocoaPods/issues/1493)
  [#1484](https://github.com/CocoaPods/CocoaPods/issues/1484)

###### Bug Fixes

* The architecture is now set in the build settings of the user build
  configurations.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1450](https://github.com/CocoaPods/CocoaPods/issues/1462)
  [#1462](https://github.com/CocoaPods/CocoaPods/issues/1462)

* Fixed a crash related to CocoaPods being unable to resolve an unique build
  setting of an user target with custom build configurations.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1462](https://github.com/CocoaPods/CocoaPods/issues/1462)
  [#1463](https://github.com/CocoaPods/CocoaPods/issues/1463)
  [#1457](https://github.com/CocoaPods/CocoaPods/issues/1457)

* Fixed a defect which prevented subspecs from being dependant on a pod with a
  name closely matching the name of one of the subspec's parents.  
  [Noah McCann](https://github.com/nmccann)
  [#29](https://github.com/CocoaPods/Core/pull/29)

* The developer dir relative to the SDK is not added anymore if testing
  frameworks are detected in OS X targets, as it doesn't exists, avoiding the
  presentation of the relative warning in Xcode.  
  [Fabio Pelosin](https://github.com/fabiopelosin)


## 0.26.2
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.26.1...0.26.2)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.26.1...0.26.2)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.11.1...0.13.0)

###### Bug Fixes

* Fixed a crash which was causing a failure in `pod lib create` if the name of
  the Pod included spaces. As spaces are not supported now this is gracefully
  handled with an informative message.  
  [Kyle Fuller](https://github.com/kylef)
  [#1456](https://github.com/CocoaPods/CocoaPods/issues/1456)

* If an user target doesn't specify an architecture the value specified for the
  project is used in CocoaPods targets.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1450](https://github.com/CocoaPods/CocoaPods/issues/1450)

* The Pods project now properly configures ARC on all build configurations.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1454](https://github.com/CocoaPods/CocoaPods/issues/1454)


## 0.26.1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.25.0...0.26.1)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.25.0...0.26.1)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.11.1...0.12.0)

###### Enhancements

* CocoaPods now creates and hides the schemes of its targets after every
  installation. The schemes are not shared because the flag which keeps track
  whether they should be visible is a user only flag. The schemes are still
  present and to debug a single Pod it is possible to make its scheme visible
  in the Schemes manager of Xcode. This is rarely needed though because the
  user targets trigger the compilation of the Pod targets.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1185](https://github.com/CocoaPods/CocoaPods/pull/1185)

* Installations which don't integrate a user target (lint subcommands and
  `--no-integrate` option) now set the architecture of OS X Pod targets to
  `$(ARCHS_STANDARD_64_BIT)` (Xcode 4 default value for new targets). This
  fixes lint issues with Xcode 4.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1185](https://github.com/CocoaPods/CocoaPods/pull/1185)

* Further improvements to the organization of the Pods project  

  - The project is now is sorted by name with groups at the bottom.
  - Source files are now stored in the root group of the spec, subspecs are not
    stored in a `Subspec` group anymore and the products of the Pods all are
    stored in the products group of the project.
  - The frameworks are referenced relative to the Developer directory and
    namespaced per platform.

  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1389](https://github.com/CocoaPods/CocoaPods/pull/1389)
  [#1420](https://github.com/CocoaPods/CocoaPods/pull/1420)

* Added the `documentation_url` DSL attribute to the specifications.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1273](https://github.com/CocoaPods/CocoaPods/pull/1273)

###### Bug Fixes

* The search paths of vendored frameworks and libraries now are always
  specified relatively.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1405](https://github.com/CocoaPods/CocoaPods/pull/1405)

* Fix an issue where CocoaPods would fail to work when used with an older
  version of the Active Support gem. This fix raises the dependency version to
  the earliest compatible version of Active Support.  
  [Kyle Fuller](https://github.com/kylef)
  [#1407](https://github.com/CocoaPods/CocoaPods/issues/1407)

* CocoaPods will not attempt to load anymore all the version of a specification
  preventing crashes if those are incompatible.  
  [Fabio Pelosin](https://github.com/fabiopelosin)
  [#1272](https://github.com/CocoaPods/CocoaPods/pull/1272)


## 0.25.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.24.0...0.25.0)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.24.0...0.25.0)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.10.1...0.11.0)

###### Enhancements

* Added support for Xcode 5.

  The generated Pods Xcode project is now compatible with `arm64` projects and
  is updated to use Xcode 5’s default settings removing all warnings.

  **NOTE to users migrating projects from Xcode 4, or are still using Xcode 4:**
  1. The Pods Xcode project now sets the `ONLY_ACTIVE_ARCH` build setting to
     `YES` in the `Debug` configuration. You _will_ have to set the same on your
     project/target, otherwise the build _will_ fail.
  2. Ensure your project/target has an `ARCHS` value set, otherwise the build
     _will_ fail.
  3. When building a **iOS** project from the command-line, with the `xcodebuild`
     tool that comes with Xcode 4, you’ll need to completely disable this setting
     by appending to your build command: `ONLY_ACTIVE_ARCH=NO`.

  [#1352](https://github.com/CocoaPods/CocoaPods/pull/1352)

* Speed up project generation in `pod install` and `pod update`.

* The pre and post install hooks that have been deprecated now include the name
  and version of the spec that’s using them.

###### Bug Fixes

* Only create a single resource bundle for all targets. Prior to this change a
  resource bundle included into multiple targets within the project would create
  duplicately named targets in the Pods Xcode project, causing duplicately named
  Schemes to be created on each invocation of `pod install`. All targets that
  reference a given resource bundle now have dependencies on a single common
  target.

  [Blake Watters](https://github.com/blakewatters)
  [#1338](https://github.com/CocoaPods/CocoaPods/issues/1338)

* Solved outstanding issues with CocoaPods resource bundles and Archive builds:
  1. The rsync task copies symlinks into the App Bundle, producing an invalid
     app. This change add `--copy-links` to the rsync invocation to ensure the
     target files are copied rather than the symlink.
  2. The Copy Resources script uses `TARGET_BUILD_DIR` which points to the App
     Archiving folder during an Archive action. Switching to
     `BUILT_PRODUCTS_DIR` instead ensures that the path is correct for all
     actions and configurations.

  [Blake Watters](https://github.com/blakewatters)
  [#1309](https://github.com/CocoaPods/CocoaPods/issues/1309)
  [#1329](https://github.com/CocoaPods/CocoaPods/issues/1329)

* Ensure resource bundles are copied to installation location on install actions
  [Chris Gummer](https://github.com/chrisgummer)
  [#1364](https://github.com/CocoaPods/CocoaPods/issues/1364)

* Various bugfixes in Xcodeproj, refer to its [CHANGELOG](https://github.com/CocoaPods/Xcodeproj/blob/0.11.0/CHANGELOG.md)
  for details.


## 0.24.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.22.3...0.23.0.rc1)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.22.3...0.23.0.rc1)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.8.1...0.9.0)
• [cocoapods-downloader](https://github.com/CocoaPods/cocoapods-downloader/compare/0.1.1...0.2.0)

###### Enhancements

* Added `pod init` command which generates a Podfile according to the
  targets of the project stored in the working directory and to the templates
  stored in the `~/.cocoapods/templates` folder. Two templates are supported:
    - the `Podfile.default` template for regular targets.
    - and the `Podfile.test` template for test targets.
  [Ian Ynda-Hummel](https://github.com/ianyh)
  [#1106](https://github.com/CocoaPods/CocoaPods/issues/1106)
  [#1045](https://github.com/CocoaPods/CocoaPods/issues/1045)

* CocoaPods will now leverage the [xcproj](https://github.com/0xced/xcproj)
  command line tool if available in the path of the user to touch saved
  projects. This will result in projects being serialized in the exact format
  used by Xcode eliminating merge conflicts and other related issues. To learn
  more about how to install xcproj see its
  [readme](https://github.com/0xced/xcproj).
  [Cédric Luthi](https://github.com/0xced)
  [#1275](https://github.com/CocoaPods/CocoaPods/issues/1275)

* Rationalized and cleaned up Pods project group structure and path specification.

* Create all necessary build configurations for *Pods.xcodeproj* at the project level. If the user’s project has more than just *Debug* and *Release* build configurations, they may be explicitly specified in the Podfile:  
`xcodeproj 'MyApp', 'App Store' => :release, 'Debug' => :debug, 'Release' => :release`  
  If build configurations aren’t specified in the Podfile then they will be automatically picked from the user’s project in *Release* mode.  
  These changes will ensure that the `libPods.a` static library is not stripped for all configurations, as explained in [#1217](https://github.com/CocoaPods/CocoaPods/pull/1217).  
  [Cédric Luthi](https://github.com/0xced)  
  [#1294](https://github.com/CocoaPods/CocoaPods/issues/1294)

* Added basic support for Bazaar repositories.  
  [Fred McCann](https://github.com/fmccann)  
  [cocoapods-downloader#4](https://github.com/CocoaPods/cocoapods-downloader/pull/4)

###### Bug Fixes

* Fixed crash in `pod spec cat`.

* Use the `TARGET_BUILD_DIR` environment variable for installing resource bundles.  
  [Cédric Luthi](https://github.com/0xced)  
  [#1268](https://github.com/CocoaPods/CocoaPods/issues/1268)  

* CoreData versioned models are now properly handled respecting the contents of
  the `.xccurrentversion` file.  
  [Ashton-W](https://github.com/Ashton-W)  
  [#1288](https://github.com/CocoaPods/CocoaPods/issues/1288),
  [Xcodeproj#83](https://github.com/CocoaPods/Xcodeproj/pull/83)  

* OS X frameworks are now copied to the Resources folder using rsync to
  properly overwrite existing files.  
  [Nikolaj Schumacher](https://github.com/nschum)  
  [#1063](https://github.com/CocoaPods/CocoaPods/issues/1063)

* User defined build configurations are now added to the resource bundle
  targets.  
  [#1309](https://github.com/CocoaPods/CocoaPods/issues/1309)


## 0.23.0


## 0.23.0.rc1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.22.3...0.23.0.rc1)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.22.3...0.23.0.rc1)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.8.1...0.9.0)
• [cocoapods-downloader](https://github.com/CocoaPods/cocoapods-downloader/compare/0.1.1...0.1.2)

###### Enhancements

* Added `prepare_command` attribute to Specification DSL. The prepare command
  will replace the `pre_install` hook. The `post_install` hook has also been
  deprecated.
  [#1247](https://github.com/CocoaPods/CocoaPods/issues/1247)

  The reason we provided Ruby hooks at first, was because we wanted to offer
  the option to make any required configuration possible. By now, however, we
  have a pretty good idea of the use-cases and are therefore locking down the
  freedom that was once available. In turn, we’re adding attributes that can
  replace the most common use-cases. _(See the enhancements directly following
  this entry for more info)._

  The second reason we need to lock this down is because this is the last
  remaining obstacle to fully serialize specifications, which we need in order
  to move to a ‘spec push’ web-service in the future.

* Added `resource_bundles` attribute to the Specification DSL.  
  [#743](https://github.com/CocoaPods/CocoaPods/issues/743)
  [#1186](https://github.com/CocoaPods/CocoaPods/issues/1186)

* Added `vendored_frameworks` attribute to the Specification DSL.  
  [#809](https://github.com/CocoaPods/CocoaPods/issues/809)
  [#1075](https://github.com/CocoaPods/CocoaPods/issues/1075)

* Added `vendored_libraries` attribute to the Specification DSL.  
  [#809](https://github.com/CocoaPods/CocoaPods/issues/809)
  [#1075](https://github.com/CocoaPods/CocoaPods/issues/1075)

* Restructured `.cocoapods` folder to contain repos in a subdirectory.  
  [Ian Ynda-Hummel](https://github.com/ianyh)
  [#1150](https://github.com/CocoaPods/CocoaPods/issues/1150)  

* Improved `pod spec create` template.  
  [#1223](https://github.com/CocoaPods/CocoaPods/issues/1223)

* Added copy&paste-friendly dependency to `pod search`.  
  [#1073](https://github.com/CocoaPods/CocoaPods/issues/1073)

* Improved performance of the installation of Pods with git
  sources which specify a tag.  
  [#1077](https://github.com/CocoaPods/CocoaPods/issues/1077)

* Core Data `xcdatamodeld` files are now properly referenced from the Pods
  project.  
  [#1155](https://github.com/CocoaPods/CocoaPods/issues/1155)

* Removed punctuation check from the specification validations.  
  [#1242](https://github.com/CocoaPods/CocoaPods/issues/1242)

* Deprecated the `documentation` attribute of the Specification DSL.  
  [Core#20](https://github.com/CocoaPods/Core/issues/20)

###### Bug Fixes

* Fix copy resource script issue related to filenames with spaces.  
  [Denis Hennessy](https://github.com/dhennessy)
  [#1231](https://github.com/CocoaPods/CocoaPods/issues/1231)  



## 0.22.3
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.22.2...0.22.3)

###### Enhancements

* Add support for .xcdatamodel resource files (in addition to .xcdatamodeld).
  [#1201](https://github.com/CocoaPods/CocoaPods/pull/1201)

###### Bug Fixes

* Always exlude `USE_HEADERMAP` from the user’s project.
  [#1216](https://github.com/CocoaPods/CocoaPods/issues/1216)

* Use correct template repo when using the `pod lib create` command.
  [#1214](https://github.com/CocoaPods/CocoaPods/issues/1214)

* Fixed issue with `pod push` failing when the podspec is unchanged. It will now
  report `[No change] ExamplePod (0.1.0)` and continue to push other podspecs if
  they exist. [#1199](https://github.com/CocoaPods/CocoaPods/pull/1199)

* Set STRIP_INSTALLED_PRODUCT = NO in the generated Pods project. This allows
  Xcode to include symbols from CocoaPods in dSYMs during Archive builds.
  [#1217](https://github.com/CocoaPods/CocoaPods/pull/1217)

* Ensure the resource script doesn’t fail due to the resources list file not
  existing when trying to delete it.
  [#1198](https://github.com/CocoaPods/CocoaPods/pull/1198)

* Fix handling of spaces in paths when compiling xcdatamodel(d) files.
  [#1201](https://github.com/CocoaPods/CocoaPods/pull/1201)



## 0.22.2
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.22.1...0.22.2)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.22.1...0.22.2)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.8.0...0.8.1)

###### Enhancements

* The build settings of the Pods project and of its target have been updated to
  be in line with the new defaults of the future versions of Xcode.

###### Bug fixes

* Specifications defining build setting with the `[*]` syntax are now properly
  handled.
  [#1171](https://github.com/CocoaPods/CocoaPods/issues/1171)

* The name of the files references are now properly set fixing a minor
  regression introduced by CocoaPods 0.22.1 and matching more closely Xcode
  behaviour.

* The validator now builds the Pods target instead of the first target actually
  performing the validation.

* Build settings defined through the `xcconfig` attribute of a `podspec` are now
  stripped of duplicate values when merged in an aggregate target.
  [#1189](https://github.com/CocoaPods/CocoaPods/issues/1189)


## 0.22.1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.22.0...0.22.1)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.22.0...0.22.1)

###### Bug fixes

* Fixed a crash related to target dependencies and subspecs.
  [#1168](https://github.com/CocoaPods/CocoaPods/issues/1168)


## 0.22.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.21.0...0.22.0)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.21.0...0.22.0)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.7.1...0.8.0)

###### Enhancements

* Added the `pod lib create` subcommand which allows to create a new Pod
  adhering to the best practices. The template is still a bit primitive
  and we encourage users to provide feedback by submitting patches and issues
  to https://github.com/CocoaPods/CocoaPods.
  [#850](https://github.com/CocoaPods/CocoaPods/issues/850)

* Added the `pod lib lint` subcommand which allows to lint the Pod stored
  in the working directory (a pod spec in the root is needed). This subcommand
  is equivalent to the deprecated `pod spec lint --local`.
  [#850](https://github.com/CocoaPods/CocoaPods/issues/850)

* The dependencies of the targets of the Pods project are now made explicit.
  [#1165](https://github.com/CocoaPods/CocoaPods/issues/1165)

* The size of the cache used for the git repos is now configurable. For more
  details see
  https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/config.rb#L7-L25
  [#1159](https://github.com/CocoaPods/CocoaPods/issues/1159)

* The copy resources shell script now aborts if any error occurs.
  [#1098](https://github.com/CocoaPods/CocoaPods/issues/1098)

* The output of shell script build phases no longer includes environment
  variables to reduce noise.
  [#1122](https://github.com/CocoaPods/CocoaPods/issues/1122)

* CocoaPods no longer sets the deprecated `ALWAYS_SEARCH_USER_PATHS` build
  setting.

###### Bug fixes

* Pods whose head state changes now are correctly detected and reinstalled.
  [#1160](https://github.com/CocoaPods/CocoaPods/issues/1160)

* Fixed the library reppresentation of the hooks which caused issues with the
  `#copy_resources_script_path` method.
  [#1157](https://github.com/CocoaPods/CocoaPods/issues/1157)

* Frameworks symlinks are not properly preserved by the copy resources script.
  Thanks to Thomas Dohmke (ashtom) for the fix.
  [#1063](https://github.com/CocoaPods/CocoaPods/issues/1063)

## 0.21.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.21.0.rc1...0.21.0)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.21.0.rc1...0.21.0)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.7.0...0.7.1)

###### Bug fixes

* Fixed a linter issue related to the dedicated targets change.
  [#1130](https://github.com/CocoaPods/CocoaPods/issues/1130)

* Fixed xcconfig issues related to Pods including a dot in the name.
  [#1152](https://github.com/CocoaPods/CocoaPods/issues/1152)


## 0.21.0.rc1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.20.2...0.21.0.rc1)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.20.2...0.21.0.rc1)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.6.0...0.7.0)

###### Enhancements

* Pods are now built in dedicated targets. This enhancement isolates the build
  environment of each Pod from other ones eliminating pollution issues. It also
  introduces an important architectural improvement which lays the foundation
  for the upcoming CocoaPods features. Stay tuned! This feature has been
  implemented by [Jeremy Slater](https://github.com/jasl8r).
  [#1011](https://github.com/CocoaPods/CocoaPods/issues/1011)
  [#983](https://github.com/CocoaPods/CocoaPods/issues/983)
  [#841](https://github.com/CocoaPods/CocoaPods/issues/841)

* Reduced external dependencies and deprecation of Rake::FileList.
  [#1080](https://github.com/CocoaPods/CocoaPods/issues/1080)

###### Bug fixes

* Fixed crash due to Podfile.lock containing multiple version requirements for
  a Pod. [#1076](https://github.com/CocoaPods/CocoaPods/issues/1076)

* Fixed a build error due to the copy resources script using the same temporary
  file for multiple targets.
  [#1099](https://github.com/CocoaPods/CocoaPods/issues/1099)

## 0.20.2
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.20.1...0.20.2)

###### Bug fixes

* Ensure that, in a sandbox-pod env, RubyGems loads the CocoaPods gem on system
  Ruby (1.8.7).
  [#939](https://github.com/CocoaPods/CocoaPods/issues/939#issuecomment-18396063)
* Allow sandbox-pod to execute any tool inside the Xcode.app bundle.
* Allow sandbox-pod to execute any tool inside a rbenv prefix.

## 0.20.1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.20.0...0.20.1)
• [CLAide](https://github.com/CocoaPods/CLAide/compare/0.3.0...0.3.2)

###### Bug fixes

* Made sandbox-pod executable visible as it wasn't correctly configured in the
  gemspec.
* Made sandbox-pod executable actually work when installed as a gem. (In which
  case every executable is wrapped in a wrapper bin script and the DATA constant
  can no longer be used.)
* Required CLAide 0.3.2 as 0.3.0 didn't include all the files in the gemspec
  and 0.3.1 was not correctly processed by RubyGems.

## 0.20.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.19.1...0.20.0)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.19.1...0.20.0)
• [cocoapods-downloader](https://github.com/CocoaPods/CLAide/compare/0.1.0...0.1.1)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.5.5...0.6.0)
• [CLAide](https://github.com/CocoaPods/CLAide/compare/0.2.0...0.3.0)

###### Enhancements

* Introduces an experimental sandbox feature.
  [#939](https://github.com/CocoaPods/CocoaPods/issues/939)

  Let’s face it, even though we have a great community that spends an amazing
  amount of time on curating the specifications, the internet can be a hostile
  place and the community is growing too large to take a naive approach any
  longer.

  As such, we have started leveraging OS X’s sandbox facilities to disallow
  unsanctioned operations. This is still very experimental and therefore has to
  be used explicitely, for now, but that does **not** mean we don’t want you to
  start using it and **report issues**.

  To use the sandbox, simply use the `sandbox-pod` command instead. E.g.:

        $ sandbox-pod install

  In case of issues, be sure to check `/var/log/system.log` for ‘deny’ messages.
  For instance, here’s an example where the sandbox denies read access to `/`:

        May 16 00:23:35 Khaos kernel[0]: Sandbox: ruby(98430) deny file-read-data /

  **NOTE**: _The above example is actually one that we know of. We’re not sure
  yet which process causes this, but there shouldn’t be a need for any process
  to read data from the root path anyways._

  **NOTE 2**: _At the moment the sandbox is not compatible with the `:path` option
  when referencing Pods that are not stored within the directory of the Podfile._

* The naked `pod` command now defaults to `pod install`.
  [#958](https://github.com/CocoaPods/CocoaPods/issues/958)

* CocoaPods will look for the Podfile in the ancestors paths if one is
  not available in the working directory.
  [#940](https://github.com/CocoaPods/CocoaPods/issues/940)

* Documentation generation has been removed from CocoaPods as it graduated
  to CocoaDocs. This decision was taken because CocoaDocs is a much better
  solution which doesn't clutter Xcode's docsets while still allowing
  access to the docsets with Xcode and with Dash. Removing this feature
  keeps the installer leaner and easier to develop and paves the way for the
  upcoming sandbox. Private pods can use pre install hook to generate the
  documentation. If there will be enough demand this feature might be
  reintegrated as plugin (see
  [#1037](https://github.com/CocoaPods/CocoaPods/issues/1037)).

* Improved performance of the copy resources script and thus build time of
  the integrated targets. Contribution by [@onato](https://github.com/onato)
  [#1050](https://github.com/CocoaPods/CocoaPods/issues/1050).

* The changelog for the current version is printed after CocoaPods is
  installed/updated.
  [#853](https://github.com/CocoaPods/CocoaPods/issues/853).


###### Bug fixes

* Inheriting `inhibit_warnings` per pod is now working
  [#1032](https://github.com/CocoaPods/CocoaPods/issues/1032)
* Fix copy resources script for iOS < 6 and OS X < 10.8 by removing the
  `--reference-external-strings-file`
  flag. [#1030](https://github.com/CocoaPods/CocoaPods/pull/1030)
* Fixed issues with the `:head` option of the Podfile.
  [#1046](https://github.com/CocoaPods/CocoaPods/issues/1046)
  [#1039](https://github.com/CocoaPods/CocoaPods/issues/1039)

## 0.19.1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.19.0...0.19.1)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.19.0...0.19.1)

###### Bug fixes

* Project-level preprocessor macros are not overwritten anymore.
  [#903](https://github.com/CocoaPods/CocoaPods/issues/903)
* A Unique hash instances for the build settings of the Pods target is now
  created resolving interferences in the hooks.
  [#1014](https://github.com/CocoaPods/CocoaPods/issues/1014)

## 0.19.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.18.1...0.19.0)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.18.1...0.19.0)

###### Enhancements

* Compile time introspection. Macro definitions which allow to inspect the
  installed Pods and their version have been introduced in the build
  environment of the Pod libraries
  ([example](https://gist.github.com/fabiopelosin/5348551)).
* CocoaPods now defines the `COCOAPODS=1` macro in the Pod and the Client
  targets. This is useful for libraries which conditionally expose interfaces.
  [#903](https://github.com/CocoaPods/CocoaPods/issues/903)
* Added support for the `private_header_files` attribute of the Specification
  DSL.
  [#998](https://github.com/CocoaPods/CocoaPods/issues/998)
* CocoaPods now defines the deployment target of the Pods project computed as
  the minimum deployment target of the Pods libraries.
  [#556](https://github.com/CocoaPods/CocoaPods/issues/556)
* Added `pod podfile-info` command. Shows list of used Pods and their info
  in a project or supplied Podfile.
  Options: `--all` - with dependencies. `--md` - in Markdown.
  [#855](https://github.com/CocoaPods/CocoaPods/issues/855)
* Added `pod help` command. You can still use the old format
  with --help flag.
  [#957](https://github.com/CocoaPods/CocoaPods/pull/957)
* Restored support for Podfiles named `CocoaPods.podfile`. Moreover, the
  experimental YAML format of the Podfile now is associated with files named
  `CocoaPods.podfile.yaml`.
  [#1004](https://github.com/CocoaPods/CocoaPods/pull/1004)

###### Deprecations

* The `:local` flag in Podfile has been renamed to `:path` and the old syntax
  has been deprecated.
  [#971](https://github.com/CocoaPods/CocoaPods/issues/971)

###### Bug fixes

* Fixed issue related to `pod outdated` and external sources.
  [#954](https://github.com/CocoaPods/CocoaPods/issues/954)
* Fixed issue with .svn folders in copy resources script.
  [#972](https://github.com/CocoaPods/CocoaPods/issues/972)

## 0.18.1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.18.0...0.18.1)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.18.0...0.18.)

###### Bug fixes

* Fixed a bug introduced in 0.18 which cause compilation issue due to the
  quoting of the inherited value in the xcconfigs.
  [#956](https://github.com/CocoaPods/CocoaPods/issues/956)
* Robustness against user targets including build files with missing file
  references.
  [#938](https://github.com/CocoaPods/CocoaPods/issues/938)
* Partially fixed slow performance from the command line
  [#919](https://github.com/CocoaPods/CocoaPods/issues/919)


## 0.18.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.17.2...0.18.0)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.17.2...0.18.0)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.5.2...0.5.5)

###### Enhancements

* Added the ability to inhibit warnings per pod.
  Just pass `:inhibit_warnings => true` inline.
  This feature has been implemented by Marin Usalj (@mneorr).
  [#10](https://github.com/CocoaPods/Core/pull/10)
  [#934](https://github.com/CocoaPods/CocoaPods/pull/934)
* Inhibiting warnings will also suppress the warnings of the static analyzer.
* A new build phase has been added to check that your
  installation is in sync with the `Podfile.lock` and fail the build otherwise.
  The new build phase will not be added automatically to targets already
  integrated with CocoaPods, for integrating targets manually see [this
  comment](https://github.com/CocoaPods/CocoaPods/pull/946#issuecomment-16042419).
  This feature has been implemented by Ullrich Schäfer (@stigi).
  [#946](https://github.com/CocoaPods/CocoaPods/pull/946)
* The `pod search` commands now accepts the `--ios` and the `--osx` arguments
  to filter the results by platform.
  [#625](https://github.com/CocoaPods/CocoaPods/issues/625)
* The developer frameworks are automatically added if `SenTestingKit` is
  detected. There is no need to specify them in specifications anymore.
  [#771](https://github.com/CocoaPods/CocoaPods/issues/771)
* The `--no-update` argument of the `install`, `update`, `outdated` subcommands
  has been renamed to `--no-repo-update`.
  [#913](https://github.com/CocoaPods/CocoaPods/issues/913)

###### Bug fixes

* Improved handling for Xcode projects containing non ASCII characters.
  Special thanks to Cédric Luthi (@0xced), Vincent Isambart (@vincentisambart),
  and Manfred Stienstra (@Manfred) for helping to develop the workaround.
  [#926](https://github.com/CocoaPods/CocoaPods/issues/926)
* Corrected improper configuration of the PODS_ROOT xcconfig variable in
  non-integrating installations.
  [#918](https://github.com/CocoaPods/CocoaPods/issues/918)
* Improved support for pre-release versions using dashes.
  [#935](https://github.com/CocoaPods/CocoaPods/issues/935)
* Documentation sets are now namespaced by pod solving improper attribution.
  [#659](https://github.com/CocoaPods/CocoaPods/issues/659)


## 0.17.2
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.17.1...0.17.2)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.17.1...0.17.2)

###### Bug fixes

* Fix crash related to the specification of the workspace as a relative path.
  [#920](https://github.com/CocoaPods/CocoaPods/issues/920)
* Fix an issue related to the `podspec` dsl directive of the Podfile for
  specifications with internal dependencies.
  [#928](https://github.com/CocoaPods/CocoaPods/issues/928)
* Fix crash related to search from the command line.
  [#929](https://github.com/CocoaPods/CocoaPods/issues/929)

###### Ancillary enhancements

* Enabled the FileList deprecation warning in the Linter.
* CocoaPods will raise if versions requirements are specified for dependencies
  with external sources.
* The exclude patterns now handle folders automatically.


## 0.17.1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.17.0...0.17.1)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.17.0...0.17.1)

###### Bug fixes

* Always create the CACHE_ROOT directory when performing a search.
  [#917](https://github.com/CocoaPods/CocoaPods/issues/917)

## 0.17.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.17.0.rc7...0.17.0)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.17.0.rc7...0.17.0)

#### GM

###### Bug fixes

* Don’t break when specifying doc options, but not appledoc ones.
  [#906](https://github.com/CocoaPods/CocoaPods/issues/906)
* Sort resolved specifications.
  [#907](https://github.com/CocoaPods/CocoaPods/issues/907)
* Subspecs do not need to include HEAD information.
  [#905](https://github.com/CocoaPods/CocoaPods/issues/905)

###### Ancillary enhancements

* Allow the analyzer to do its work without updating sources.
  [motion-cocoapods#50](https://github.com/HipByte/motion-cocoapods/pull/50)

#### rc7
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.17.0.rc6...0.17.0.rc7)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.17.0.rc6...0.17.0.rc7)

###### Bug fixes

- Fixed an issue which lead to the missing declaration of the plural directives
  of the Specification DSL.
  [#816](https://github.com/CocoaPods/CocoaPods/issues/816)
- The resolver now respects the order of specification of the target
  definitions.
- Restore usage of cache file to store a cache for expensive stats.
- Moved declaration of `Pod::FileList` to CocoaPods-core.

###### Ancillary enhancements

- Fine tuned the Specification linter and the health reporter of repositories.
- Search results are sorted.

#### rc6
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.17.0.rc5...0.17.0.rc6)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.17.0.rc5...0.17.0.rc6)

###### Bug fixes

- CocoaPods updates the repositories by default.
  [#872](https://github.com/CocoaPods/CocoaPods/issues/872)
- Fixed a crash which was present when the Podfile specifies a workspace.
  [#871](https://github.com/CocoaPods/CocoaPods/issues/871)
- Fix for a bug which lead to a broken installation in paths containing
  brackets and other glob metacharacters.
  [#862](https://github.com/CocoaPods/CocoaPods/issues/862)
- Fix for a bug related to the case of the paths which lead to clean all files
  in the directories of the Pods.


###### Ancillary enhancements

- CocoaPods now maintains a search index which is updated incrementally instead
  of analyzing all the specs every time. The search index can be updated
  manually with the `pod ipc update-search-index` command.
- Enhancements to the `pod repo lint` command.
- CocoaPods will not create anymore the pre commit hook in the master repo
  during setup. If already created it is possible remove it deleting the
  `~/.cocoapods/master/.git/hooks/pre-commit` path.
- Improved support for linting and validating specs repo.

#### rc5
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.17.0.rc4...0.17.0.rc5)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.17.0.rc4...0.17.0.rc5)

###### Bug fixes

- The `--no-clean` argument is not ignored anymore by the installer.
- Proper handling of file patterns ending with a slash.
- More user errors are raised as an informative.

#### rc4
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.17.0.rc3...0.17.0.rc4)

###### Bug fixes

- Restored compatibility with `Podfile::TargetDefinition#copy_resources_script_name`
  in the Podfile hooks.
- Updated copy resources script so that it will use base internationalization
  [#846](https://github.com/CocoaPods/CocoaPods/issues/846)
- Robustness against an empty configuration file.
- Fixed a crash with `pod push`
  [#848](https://github.com/CocoaPods/CocoaPods/issues/848)
- Fixed an issue which lead to the creation of a Pods project which would
  crash Xcode.
  [#854](https://github.com/CocoaPods/CocoaPods/issues/854)
- Fixed a crash related to a `PBXVariantGroup` present in the frameworks build
  phase of client targets.
  [#859](https://github.com/CocoaPods/CocoaPods/issues/859)


###### Ancillary enhancements

- The `podspec` option of the `pod` directive of the Podfile DSL now accepts
  folders.

#### rc3
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.17.0.rc2...0.17.0.rc3
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.5.0...0.5.1))

###### Bug fixes

- CocoaPods will not crash anymore if the license file indicated on the spec
  doesn't exits.
- Pre install hooks are called before the Pods are cleaned.
- Fixed and issue which prevent the inclusion of OTHER_CFLAGS and
  OTHER_CPLUSPLUSFLAGS  in the release builds of the Pods project.
- Fixed `pod lint --local`
- Fixed the `--allow-warnings` of `pod push`
  [#835](https://github.com/CocoaPods/CocoaPods/issues/835)
- Added `copy_resources_script_name` to the library representation used in the
  hooks.
  [#837](https://github.com/CocoaPods/CocoaPods/issues/837)

###### Ancillary enhancements

- General improvements to `pod ipc`.
- Added `pod ipc repl` subcommand.

#### rc2
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.17.0.rc1...0.17.0.rc2)
• [cocoapods-core](https://github.com/CocoaPods/Core/compare/0.17.0.rc1...0.17.0.rc2)

###### Bug fixes

- Restored output coloring.
- Fixed a crash related to subspecs
  [#819](https://github.com/CocoaPods/CocoaPods/issues/819)
- Git repos were not cached for dependencies with external sources.
  [#820](https://github.com/CocoaPods/CocoaPods/issues/820)
- Restored support for directories for the preserve_patterns specification
  attribute.
  [#823](https://github.com/CocoaPods/CocoaPods/issues/823)

#### rc1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.16.4...0.17.0.rc1)
• [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.4.3...0.5.0)
• [cocoapods-core](https://github.com/CocoaPods/Core)
• [cocoapods-downloader](https://github.com/CocoaPods/cocoapods-downloader)

###### __Notice__

At some point in future the master repo will be switched to the YAML format of
specifications. This means that specifications with hooks (or any other kind of
dynamic logic) will not be accepted. Please let us know if there is need for
other DSL attributes or any other kind of support.

Currently the following specifications fail to load as they depended on the
CocoaPods internals and need to be updated:

- LibComponentLogging-pods/0.0.1/LibComponentLogging-pods.podspec
- RestKit/0.9.3/RestKit.podspec
- Three20/1.0.11/Three20.podspec
- ARAnalytics/1.1/ARAnalytics.podspec

Other specifications, might present compatibility issues for the reasons
presented below.

###### __Breaking__

- Subspecs do **not** inherit the files patterns from the parent spec anymore.
  This feature made the implementation more complicated and was not easy to
  explain to podspecs maintainers. Compatibility can be easily fixed by adding
  a 'Core' subspec.
- Support for inline podspecs has been removed.
- The support for Rake::FileList is being deprecated, in favor of a more
  consistent DSL. Rake::FileList also presented issues because it would access
  the file system as soon as it was converted to an array.
- The hooks architecture has been re-factored and might present
  incompatibilities (please open an issue if appropriate).
- The `requires_arc` attribute default value is transitioning from `false` to
  `true`. In the meanwhile a value is needed to pass the lint.
- Deprecated `copy_header_mapping` hook.
- Deprecated `exclude_header_search_paths` attribute.
- External sources are not supported in the dependencies of specifications
  anymore. Actually they never have been supported, they just happened to work.

###### DSL

- Podfile:
  - It is not needed to specify the platform anymore (unless not integrating)
    as CocoaPods now can infer the platform from the integrated targets.
- Specification:
  - `preferred_dependency` has been renamed to `default_subspec`.
  - Added `exclude_files` attribute.
  - Added `screenshots` attribute.
  - Added default values for attributes like `source_files`.

###### Enhancements

- Released preview [documentation](http://docs.cocoapods.org).
- CocoaPods now has support for working in teams and not committing the Pods
  folder, as it will keep track of the status of the Pods folder.
  [#552](https://github.com/CocoaPods/CocoaPods/issues/552)
- Simplified installation: no specific version of ruby gems is required anymore.
- The workspace is written only if needed greatly reducing the occasions in
  which Xcode asks to revert.
- The Lockfile is sorted reducing the SCM noise.
  [#591](https://github.com/CocoaPods/CocoaPods/issues/591)
- Added Podfile, Frameworks, and Resources to the Pods project.
  [#647](https://github.com/CocoaPods/CocoaPods/issues/647)
  [#588](https://github.com/CocoaPods/CocoaPods/issues/588)
- Adds new subcommand `pod spec cat NAME` to print a spec file to standard output.
- Specification hooks are only called when the specification is installed.
- The `--no-clean` option of the `pod spec lint` command now displays the Pods
  project for inspection.
- It is now possible to specify default values for the configuration in
  `~/.cocoapods/config.yaml` ([default values](https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/config.rb#L17)).
- CocoaPods now checks the checksums of the installed specifications and
  reinstalls them if needed.
- Support for YAML formats of the Podfile and the Specification.
- Added new command `pod ipc` to provide support for inter process
  communication through YAML formats.
- CocoaPods now detects if the folder of a Pod is empty and reinstalls it.
  [#534](https://github.com/CocoaPods/CocoaPods/issues/534)
- Install hooks and the `prefix_header_contents` attribute are supported in subspecs.
  [#617](https://github.com/CocoaPods/CocoaPods/issues/617)
- Dashes are now supported in the versions of the Pods.
  [#293](https://github.com/CocoaPods/CocoaPods/issues/293)

###### Bug fixes

- CocoaPods is not confused anymore by target definitions with different activated subspec.
  [#535](https://github.com/CocoaPods/CocoaPods/issues/535)
- CocoaPods is not confused anymore by to dependencies from external sources.
  [#548](https://github.com/CocoaPods/CocoaPods/issues/548)
- The git cache will always update against the remote if a tag is requested,
  resolving issues where library maintainers where updating the tag after a
  lint and would be confused by CocoaPods using the cached commit for the tag.
  [#407](https://github.com/CocoaPods/CocoaPods/issues/407)
  [#596](https://github.com/CocoaPods/CocoaPods/issues/596)

###### Codebase

- Major clean up and refactor of the whole code base.
- Extracted the core classes into
  [cocoapods-core](https://github.com/CocoaPods/Core) gem.
- Extracted downloader into
  [cocoapods-downloader](https://github.com/CocoaPods/cocoapods-downloader).
- Extracted command-line command & option handling into
  [CLAide](https://github.com/CocoaPods/CLAide).

## 0.16.4
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.16.3...0.16.4)

###### Enhancements

- Add explicit flattening option to `Downloader:Http`: `:flatten => true`.
  [#814](https://github.com/CocoaPods/CocoaPods/pull/814)
  [#812](https://github.com/CocoaPods/CocoaPods/issues/812)
  [#1314](https://github.com/CocoaPods/Specs/pull/1314)

###### Bug fixes

- Explicitely require `date` in the gemspec for Ruby 2.0.0.
  [34da3f7](https://github.com/CocoaPods/CocoaPods/commit/34da3f792b2a36fafacd4122e29025c9cf2ff38d)

## 0.16.3
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.16.2...0.16.3) • [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.4.3...0.5.0)

###### Bug fixes

- Only flatten tarballs, **not** zipballs, from HTTP sources. A zipball can
  contain single directories in the root that should be preserved, for instance
  a framework bundle. This reverts part of the change in 0.16.1.
  **NOTE** This will break some podspecs that were changed after 0.16.1.
  [#783](https://github.com/CocoaPods/CocoaPods/pull/783)
  [#727](https://github.com/CocoaPods/CocoaPods/issues/727)
- Never consider aggregate targets in the user’s project for integration.
  [#729](https://github.com/CocoaPods/CocoaPods/issues/729)
  [#784](https://github.com/CocoaPods/CocoaPods/issues/784)
- Support comments on all build phases, groups and targets in Xcode projects.
  [#51](https://github.com/CocoaPods/Xcodeproj/pull/51)
- Ensure default Xcode project values are copied before being used.
  [b43087c](https://github.com/CocoaPods/Xcodeproj/commit/b43087cb342d8d44b491e702faddf54a222b23c3)
- Block assertions in Release builds.
  [#53](https://github.com/CocoaPods/Xcodeproj/pull/53)
  [#803](https://github.com/CocoaPods/CocoaPods/pull/803)
  [#802](https://github.com/CocoaPods/CocoaPods/issues/802)


###### Enhancements

- Compile Core Data model files.
  [#795](https://github.com/CocoaPods/CocoaPods/pull/795)
- Add `Xcodeproj::Differ`, which shows differences between Xcode projects.
  [308941e](https://github.com/CocoaPods/Xcodeproj/commit/308941eeaa3bca817742c774fd584cc5ab1c8f84)


## 0.16.2
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.16.1...0.16.2) • [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.4.1...0.4.3)

###### Bug fixes

- Quote storyboard and xib paths in ‘copy resource’ script.
  [#740](https://github.com/CocoaPods/CocoaPods/pull/740)
- Fix use of `podspec` directive in Podfile with no options specified.
  [#768](https://github.com/CocoaPods/CocoaPods/pull/768)
- Generate Mac OS X Pods target with the specified deployment target.
  [#757](https://github.com/CocoaPods/CocoaPods/issues/757)
- Disable libSystem objects for ARC libs that target older platforms.
  This applies when the deployment target is set to < iOS 6.0 or OS X 10.8,
  or not specified at all.
  [#352](https://github.com/CocoaPods/Specs/issues/352)
  [#1161](https://github.com/CocoaPods/Specs/pull/1161)
- Mark header source files as ‘Project’ not ‘Public’.
  [#747](https://github.com/CocoaPods/CocoaPods/issues/747)
- Add `PBXGroup` as acceptable `PBXFileReference` value.
  [#49](https://github.com/CocoaPods/Xcodeproj/pull/49)
- Make `xcodeproj show` without further arguments actually work.
  [#45](https://github.com/CocoaPods/Xcodeproj/issues/45)

###### Enhancements

- Added support for pre-download over Mercurial.
  [#750](https://github.com/CocoaPods/CocoaPods/pull/750)

## 0.16.1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.16.0...0.16.1) • [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.4.0...0.4.1)

###### Bug fixes

- After unpacking source from a HTTP location, move the source into the parent
  dir if the archive contained only one child. This is done to make it
  consistent with how source from other types of locations are described in a
  podspec.
  **NOTE** This might break some podspecs that assumed the incorrect layout.
  [#727](https://github.com/CocoaPods/CocoaPods/issues/727)
  [#728](https://github.com/CocoaPods/CocoaPods/pull/728)
- Remove duplicate option in `pod update` command.
  [#725](https://github.com/CocoaPods/CocoaPods/issues/725)
- Memory fixes in Xcodeproj.
  [#43](https://github.com/CocoaPods/Xcodeproj/pull/43)

###### Xcodeproj Enhancements

- Sort contents of xcconfig files by setting name.
  [#591](https://github.com/CocoaPods/CocoaPods/issues/591)
- Add helpers to get platform name, deployment target, and frameworks build phases
- Take SDKROOT into account when adding frameworks.

## 0.16.0
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.16.0.rc5...master)

###### Enhancements

- Use Rake 0.9.4
  [#657](https://github.com/CocoaPods/CocoaPods/issues/657)

## 0.16.0.rc5
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.16.0.rc4...0.16.0.rc5)

###### Deprecated

- The usage of specifications defined in a Podfile is deprecated. Use the
  `:podspec` option with a file path instead. Complete removal will most
  probably happen in 0.17.0.
  [#549](https://github.com/CocoaPods/CocoaPods/issues/549)
  [#616](https://github.com/CocoaPods/CocoaPods/issues/616)
  [#525](https://github.com/CocoaPods/CocoaPods/issues/525)

###### Bug fixes

- Always consider inline podspecs as needing installation.
- Fix detection when the lib has already been integrated with the user’s target.
  [#643](https://github.com/CocoaPods/CocoaPods/issues/643)
  [#614](https://github.com/CocoaPods/CocoaPods/issues/614)
  [#613](https://github.com/CocoaPods/CocoaPods/issues/613)

## 0.16.0.rc4
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.16.0.rc3...0.16.0.rc4)

###### Bug fixes

- Fix for Rake 0.9.3
  [#657](https://github.com/CocoaPods/CocoaPods/issues/657)

## 0.16.0.rc3
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.16.0.rc2...0.16.0.rc3) • [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.4.0.rc1...0.4.0.rc6)

###### Enhancements

- Added support for copying frameworks to the app bundle.
  [#597](https://github.com/CocoaPods/CocoaPods/pull/597)

###### Bug fixes

- Ignore PBXReferenceProxy while integrating into user project.
  [#626](https://github.com/CocoaPods/CocoaPods/issues/626)
- Added support for PBXAggregateTarget and PBXLegacyTarget.
  [#615](https://github.com/CocoaPods/CocoaPods/issues/615)
- Added support for PBXReferenceProxy.
  [#612](https://github.com/CocoaPods/CocoaPods/issues/612)

## 0.16.0.rc2
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.16.0.rc1...0.16.0.rc2)

###### Bug fixes

- Fix for uninitialized constant Xcodeproj::Constants error.

## 0.16.0.rc1
[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.15.2...0.16.0.rc1) • [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.3.5...0.4.0.rc1)

###### Enhancements

- Xcodeproj partial rewrite.
  [#565](https://github.com/CocoaPods/CocoaPods/issues/565)
  [#561](https://github.com/CocoaPods/CocoaPods/pull/561)
  - Performance improvements in the `Generating support files` phase.
  - Better support for editing existing projects and sorting groups.

## 0.15.2

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.15.1...0.15.2)

###### Enhancements

- Added support for `.hh` headers.
  [#576](https://github.com/CocoaPods/CocoaPods/pull/576)

###### Bug fixes

- Restored support for running CocoaPods without a terminal.
  [#575](https://github.com/CocoaPods/CocoaPods/issues/575)
  [#577](https://github.com/CocoaPods/CocoaPods/issues/577)
- The git cache now always uses a barebones repo preventing a number of related issues.
  [#581](https://github.com/CocoaPods/CocoaPods/issues/581)
  [#569](https://github.com/CocoaPods/CocoaPods/issues/569)
- Improved fix for the issue that lead to empty directories for Pods.
  [#572](https://github.com/CocoaPods/CocoaPods/issues/572)
  [#602](https://github.com/CocoaPods/CocoaPods/issues/602)
- Xcodeproj robustness against invalid values, such as malformed UTF8.
  [#592](https://github.com/CocoaPods/CocoaPods/issues/592)

## 0.15.1

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.15.0...0.15.1)

###### Enhancements

- Show error if syntax error in Podfile or Podfile.lock.

###### Bug fixes

- Fixed an issue that lead to empty directories for Pods.
  [#519](https://github.com/CocoaPods/CocoaPods/issues/519)
  [#568](https://github.com/CocoaPods/CocoaPods/issues/568)
- Fixed a crash related to the RubyGems version informative.
  [#570](https://github.com/CocoaPods/CocoaPods/issues/570)
- Fixed a crash for `pod outdated`.
  [#567](https://github.com/CocoaPods/CocoaPods/issues/567)
- Fixed an issue that lead to excessively slow sets computation.

## 0.15.0

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.14.0...0.15.0) • [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.3.3...0.3.4)

###### Enhancements

- Pod `install` will update the specs repo only if needed.
  [#533](https://github.com/CocoaPods/CocoaPods/issues/533)
- CocoaPods now searches for the highest version of a Pod on all the repos.
  [#85](https://github.com/CocoaPods/CocoaPods/issues/85)
- Added a pre install hook to the Podfile and to root specifications.
  [#486](https://github.com/CocoaPods/CocoaPods/issues/486)
- Support for `header_mappings_dir` attribute in subspecs.
- Added support for linting a Podspec using the files from its folder `pod spec
  lint --local`
- Refactored UI.
- Added support for Podfiles named `CocoaPods.podfile` which allows to
  associate an editor application in Mac OS X.
  [#528](https://github.com/CocoaPods/CocoaPods/issues/528)
- Added config option to disable the new version available message.
  [#448](https://github.com/CocoaPods/CocoaPods/issues/448)
- Added support for extracting `.tar.bz2` files
  [#522](https://github.com/CocoaPods/CocoaPods/issues/522)
- Improved feedback for errors of repo subcommands.
  [#505](https://github.com/CocoaPods/CocoaPods/issues/505)


###### Bug fixes

- Subspecs namespacing has been restored.
  [#541](https://github.com/CocoaPods/CocoaPods/issues/541)
- Improvements to the git cache that should be more robust.
  [#517](https://github.com/CocoaPods/CocoaPods/issues/517)
  - In certain conditions pod setup would execute twice.
- The git cache now is updated if a branch is not found
  [#514](https://github.com/CocoaPods/CocoaPods/issues/514)
- Forcing UTF-8 encoding on licenses generation in Ruby 1.9.
  [#530](https://github.com/CocoaPods/CocoaPods/issues/530)
- Added support for `.hpp` headers.
  [#244](https://github.com/CocoaPods/CocoaPods/issues/244)

## 0.14.0

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.14.0.rc2...0.14.0) • [Xcodeproj](https://github.com/CocoaPods/Xcodeproj/compare/0.3.2...0.3.3)

###### Bug fixes

- In certain conditions the spec of an external would have been overridden
  by the spec in the root of a Pod.
  [#489](https://github.com/CocoaPods/CocoaPods/issues/489)
- CocoaPods now uses a recent version of Octokit.
  [#490](https://github.com/CocoaPods/CocoaPods/issues/490)
- Fixed a bug that caused Pods with preferred dependencies to be always
  installed.
  [Specs#464](https://github.com/CocoaPods/CocoaPods/issues/464)
- Fixed Xcode 4.4+ artwork warning.
  [Specs#508](https://github.com/CocoaPods/CocoaPods/issues/508)

## 0.14.0.rc2

[CocoaPods](https://github.com/CocoaPods/CocoaPods/compare/0.14.0.rc1...0.14.0.rc2)

###### Bug fixes

- Fix incorrect name for Pods from external sources with preferred subspecs.
  [#485](https://github.com/CocoaPods/CocoaPods/issues/485)
- Prevent duplication of Pod with a local source and mutliple activated specs.
  [#485](https://github.com/CocoaPods/CocoaPods/issues/485)
- Fixed the `uninitialized constant Pod::Lockfile::Digest` error.
  [#484](https://github.com/CocoaPods/CocoaPods/issues/484)

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
- Add meaningful error messages
  - ia podspec can’t be found in the root of an external source.
    [#385](https://github.com/CocoaPods/CocoaPods/issues/385),
    [#338](https://github.com/CocoaPods/CocoaPods/issues/338),
    [#337](https://github.com/CocoaPods/CocoaPods/issues/337).
  - a subspec name is misspelled.
    [#327](https://github.com/CocoaPods/CocoaPods/issues/327)
  - an unrecognized command and/or argument is provided.
- The subversion downloader now does an export instead of a checkout, which
  makes it play nicer with SCMs that store metadata in each directory.
  [#245](https://github.com/CocoaPods/CocoaPods/issues/245)
- Now the Podfile is added to the Pods project for convenient editing.

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
  `OTHER_LDFLAGS` if _any_ pods require ARC.

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
