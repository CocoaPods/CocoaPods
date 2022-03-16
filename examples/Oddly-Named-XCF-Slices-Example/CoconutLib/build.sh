#!/usr/bin/env sh
#
# This will build and export `CoconutLib.xcframework` to `build/CoconutLib.xcframework` including all supported slices.
#
# Note: This script expects to build using xcodebuild from Xcode 12.0 or later.
#

set -eou pipefail

rm -rf build/*

settings="SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
archiveDir="build/DerivedData/"

echo "Building xcframework slices"

xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib" -sdk iphoneos -archivePath "${archiveDir}/iOS" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib" -sdk iphonesimulator -archivePath "${archiveDir}/iOS-Simulator" $settings

archives=(iOS iOS-Simulator)

# NOTE: Debug symbol paths require absolute paths, so grab a reference to the working directory
pwd=`pwd`

args=""
for archive in "${archives[@]}"; do
    args="$args -framework ${archiveDir}/${archive}.xcarchive/Products/Library/Frameworks/CoconutLib.framework"
    
    # Append -debug-symbols argument for this archive's dSYM
    args="$args -debug-symbols ${pwd}/${archiveDir}/${archive}.xcarchive/dSYMs/CoconutLib.framework.dSYM"
done

echo "xcodebuild -create-xcframework $args -output 'build/CoconutLib.xcframework'"
xcodebuild -create-xcframework $args -output 'build/CoconutLib.xcframework'

sed -i '' 's/ios-arm64_x86_64-simulator/coconut-water/g' 'build/CoconutLib.xcframework/Info.plist'
mv 'build/CoconutLib.xcframework/ios-arm64_x86_64-simulator' 'build/CoconutLib.xcframework/coconut-water'
sed -i '' 's/ios-arm64/coconut-liquid/g' 'build/CoconutLib.xcframework/Info.plist'
mv 'build/CoconutLib.xcframework/ios-arm64' 'build/CoconutLib.xcframework/coconut-liquid'

echo "Done."
