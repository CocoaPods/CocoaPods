#!/usr/bin/env sh
#
# This will build and export `BananaLib.xcframework` to `build/BananaLib.xcframework` including all supported slices.
#
# Note: You may need to open the project and add a development team for code signing.
#

set -eou pipefail

rm -rf build/*

settings="SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES"

echo "Building xcframework slices"

DSYM_FOLDER=build/BananaLib.dSYMs

xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk iphoneos -archivePath "build/iOS" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk iphonesimulator -archivePath "build/iOS-Simulator" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' -archivePath "build/iOS-Catalyst" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk watchos -archivePath "build/watchOS" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk watchsimulator -archivePath "build/watchOS-Simulator" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk appletvos -archivePath "build/tvOS" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk appletvsimulator -archivePath "build/tvOS-Simulator" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk macosx -archivePath "build/macOS" $settings

archives=(iOS iOS-Simulator iOS-Catalyst watchOS watchOS-Simulator tvOS tvOS-Simulator macOS)

args=""
for archive in "${archives[@]}"; do
    args="$args -framework build/${archive}.xcarchive/Products/Library/Frameworks/BananaLib.framework"
done

echo "Copying bitcode symbol maps..."
for archive in "${archives[@]}"; do
    symbolmap_src="build/${archive}.xcarchive/BCSymbolMaps"
    if [[ -d "$symbolmap_src" ]]; then
        rsync -av "${symbolmap_src}/" "build/${archive}.xcarchive/Products/Library/Frameworks/BananaLib.framework/BCSymbolMaps"
    else
        echo "No bitcode symbol maps in archive ${archive}"
    fi
done


echo "xcodebuild -create-xcframework $args -output build/BananaLib.xcframework"
xcodebuild -create-xcframework $args -output build/BananaLib.xcframework

echo "Gathering dSYMs to $DSYM_FOLDER..."
mkdir $DSYM_FOLDER
for archive in "${archives[@]}"; do
    dsym_src="build/${archive}.xcarchive/dSYMs/BananaLib.framework.dSYM"
    if [[ -d "$dsym_src" ]]; then
        rsync -av "${dsym_src}/" "${DSYM_FOLDER}/${archive}.dSYM"
    else
        echo "No dSYMs in archive ${archive}"
    fi
done
