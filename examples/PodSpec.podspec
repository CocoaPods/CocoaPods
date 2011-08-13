class IcePop < Pod::Spec
  #############################################################################
  # Required attributes
  #############################################################################

  # This pod’s version.
  #
  # The version string can contain numbers and periods, such as 1.0.0. A pod is
  # a ‘prerelease’ pod if the version has a letter in it, such as 1.0.0.pre.
  version '1.0.0'

  # A short summary of this pod’s description. Displayed in `pod list -d`.
  summary 'A library that retrieves the current price of your favorite ice cream.'

  # The list of authors and their email addresses.
  #
  # This attribute is aliased as `author`, which can be used if there’s only
  # one author.
  authors 'Eloy Durán' => 'eloy.de.enige@gmail.com', 'Appie Durán' => 'appie@dekleineprins.me'

  # The download strategy and the URL of the location of this pod’s source.
  #
  # Options are:
  # * :git => 'git://example.org/ice-pop.git'
  # * :svn => 'http://example.org/ice-pop/trunk'
  # * :tar => 'http://example.org/ice-pop-1.0.0.tar.gz'
  # * :zip => 'http://example.org/ice-pop-1.0.0.zip'
  source :git => 'https://github.com/alloy/ice-pop.git'


  #############################################################################
  # Optional attributes
  #############################################################################

  # This pod’s name.
  #
  # It default to the name of the manifest class.
  name 'IcePop'

  # A long description of this pod. It should be more detailed than the summary.
  #
  # It defaults to the summary.
  description %{
    This library consumes the icecreamexchange.example.org web API to get the
    latest prices of all ice cream products known to man. While it’s being used
    in production with much success, it’s still under heavy development.
  }

  # The directories that contain this pod’s source. These will be placed in
  # the `HEADER_SEARCH_PATH`.
  #
  # It defaults to `Source`.
  #
  # The attribute is aliased to `source_dir`, which can be used if there’s only
  # one directory.
  source_dirs 'Source/Controllers', 'Source/Models'

  # The platforms this pod compiles for.
  #
  # It defaults to `OSX`.
  #
  # The attribute is aliased to `platform`, which can be used if there’s only
  # one platform.
  platforms 'OSX', 'iPhone'

  # The SDK needed to compile this pod’s source.
  sdk '>= 10.7'

  # The URL of this pod’s home page
  homepage 'http://ice-pop.example.org'

  # Adds a runtime dependency with version requirements to this pod. You can
  # add as much dependencies as you’d like by adding extra `dependency` lines.
  #
  # TODO See version help
  dependency 'AsyncSocket', '~> 0.6', '>= 0.6.3'

  # Adds a development dependency to this pod. These are *not* needed by the
  # end-user, but only for development of this pod itself.
  #
  # You can create as many groups as you’d like, however, the `development`
  # group is assumed, by CocoaPod, to be a set of dependencies for development
  # of this pod itself.
  group :development do
    dependency 'FakeServer', '>= 1'
  end

  # The tool that should be used to generate documentation from this pod’s
  # header files.
  #
  # It defaults to `appledoc`.
  doc_bin 'appledoc'

  # The options passed to the `doc_bin` tool when generating documentation from
  # this pod’s header files.
  #
  # It defaults to options for `appledoc` that set the project name and version.
  #
  # The options specified will be _merged_ with the defaults.
  #
  # The attribute is aliased to `doc_option`, which can be used if there’s only
  # one option.
  doc_options '--project-name' => 'IcePop', '--project-version' => '1.0.0'

  # Sets whether or not this pod comes with runnable tests.
  #
  # It defaults to `false`.
  has_tests true

  # The tool used to run this pod’s tests.
  #
  # It defaults to `xcodebuild`.
  test_bin 'xcodebuild'

  # The options passed to the `test_bin` tool when running this pod’s tests.
  #
  # It defaults to options for `xcodebuil` that set the Xcode project file and
  # the name of the target that runs the tests.
  #
  # The options specified will be _merged_ with the defaults.
  #
  # The attribute is aliased to `test_option`, which can be used if there’s
  # only one option.
  test_options '-project' => 'IcePop.xcodeproj', '-target' => 'Test'
end

