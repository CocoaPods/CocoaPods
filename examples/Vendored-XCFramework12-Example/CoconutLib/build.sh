#!/usr/bin/env sh
#
# This will build and export `CoconutLib.xcframework` to `build/CoconutLib.xcframework` including all supported slices.
#
# Note: This script expects to build using xcodebuild from Xcode 12.0 or later.
#

set -eou pipefail

rm -rf build/*

settings="SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES"

echo "Building xcframework slices"

xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib" -sdk iphoneos -archivePath "build/iOS" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib" -sdk iphonesimulator -archivePath "build/iOS-Simulator" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib" -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' -archivePath "build/iOS-Catalyst" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib" -sdk watchos -archivePath "build/watchOS" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib" -sdk watchsimulator -archivePath "build/watchOS-Simulator" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib" -sdk appletvos -archivePath "build/tvOS" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib" -sdk appletvsimulator -archivePath "build/tvOS-Simulator" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib" -sdk macosx -archivePath "build/macOS" $settings

archives=(iOS iOS-Simulator iOS-Catalyst watchOS watchOS-Simulator tvOS tvOS-Simulator macOS)

# NOTE: Debug symbol paths require absolute paths, so grab a reference to the working directory
pwd=`pwd`

args=""
for archive in "${archives[@]}"; do
    args="$args -framework build/${archive}.xcarchive/Products/Library/Frameworks/CoconutLib.framework"
    
    # Append -debug-symbols argument for this archive's dSYM
    args="$args -debug-symbols ${pwd}/build/${archive}.xcarchive/dSYMs/CoconutLib.framework.dSYM"

    # Append -debug-symbols argument for this archive's BCSymbolMaps, if they exist (device builds only)
    bcsymbolMapDir="build/${archive}.xcarchive/BCSymbolMaps"
    if test -d "${bcsymbolMapDir}"; then
        for symbolMap in "${bcsymbolMapDir}"/*; do
            args="$args -debug-symbols ${pwd}/${symbolMap}"
        done
    fi
done

echo "xcodebuild -create-xcframework $args -output 'build/CoconutLib.xcframework'"
xcodebuild -create-xcframework $args -output 'build/CoconutLib.xcframework'

echo "Done."
