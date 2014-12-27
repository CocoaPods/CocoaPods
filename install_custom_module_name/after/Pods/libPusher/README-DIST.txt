===============================================================================
README: libPusher distribution build
===============================================================================

This package contains three static libraries:

* libPusher-iphoneosXXa
* libPusher-iphonesimulatorXX.a
* libPusher-combined.a

Where XX is the version of the SDK that the library was compiled with.

It also contains a number of public headers that you will need in order to use the library in your project.

The iphoneos library is compiled for armv7 devices and the iphonesimulator library is compiled for the simulator. You may use these if you wish to link to them separately for different targets in your project.

Most people will want to use the combined library, which is a fat static library that will run on both the simulator and the device.

===============================================================================
Installation
===============================================================================

These instructions use the combined library:

1. Copy the libPusher-combined.a library in to your project. 

2. In your target settings, under the Build Phases tab, expand "Link Binary With Libraries" and check that libPusher-combined.a appears there. If it does not, click the "+" symbol and add it. This links your target with the static library.

3. In your target build settings, locate the "Other Linker Flags" setting and add "-all_load".

4. Drag the contents of the headers directory into your project.

5. Link with the following libraries/frameworks:

* libicucore.dylib
* CFNetwork.framework
* Security.framework
* SystemConfiguration.framework

6. You should now be able to #import "PTPusher.h" and compile.

===============================================================================
Notes
===============================================================================

If you are upgrading, libPusher no longer uses the JSONKit library and the static library no longer contains a compiled version of JSONKit.m.

By default, libPusher now uses NSJSONSerialization which is available on iOS 5.0 or OSX 10.7 and later. If you require support for older platforms, libPusher still has support for JSONKit as a fallback option, but you are required to link JSONKit to your app separately.

For more information, see:
https://github.com/lukeredpath/libPusher/wiki/Adding-libPusher-to-your-project

