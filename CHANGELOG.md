## Installation & Update

To install or update CocoaPods see this [guide](http://docs.cocoapods.org/guides/installing_cocoapods.html).

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
  ([example](https://gist.github.com/irrationalfab/5348551)).
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
