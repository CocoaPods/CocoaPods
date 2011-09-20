This is the example that comes with [AFNetworking][url] updated to use CocoaPods.

To build it, you'll first have to install the app's dependencies. From the
example directory, in the terminal, run the following command:

    $ pod install

This has generated the contents of the `Pods` directory, which contains an Xcode
project that is included in the `AFNetworking Example.xcworkspace` and which
will make sure the dependencies are build before the app is build.

Go ahead, open the workspace and build it.


### These are the steps I had to perform to update the project:

1. remove Vendor, delete files
2. remove libz from build phases => libraries
3. remove ‘always search user header paths’ setting (normally not needed)
4. create Podfile with:

      dependency 'AFNetworking'
      dependency 'JSONKit'
      dependency 'FormatterKit'

5. $ pod install
6. Follow steps from the [‘In Xcode’ section][more].


[url]: https://github.com/gowalla/AFNetworking/tree/master/Example
[more]: https://github.com/alloy/cocoapods/wiki/Creating-a-project-that-uses-CocoaPods
