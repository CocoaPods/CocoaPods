#!/usr/bin/env sh
#
# This will build and export `BananaLib.xcframework` to `build/BananaLib.xcframework` including all supported slices.
#
# Note: You may need to open the project and add a development team for code signing.
#

set -eou pipefail

rm -rf build/*

settings="SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
archiveDir="build/DerivedData/"

echo "Building xcframework slices"

DSYM_FOLDER="build/BananaLib.dSYMs"

xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk iphoneos -archivePath "${archiveDir}/iOS" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk iphonesimulator -archivePath "${archiveDir}/iOS-Simulator" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' -archivePath "${archiveDir}/iOS-Catalyst" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk watchos -archivePath "${archiveDir}/watchOS" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk watchsimulator -archivePath "${archiveDir}/watchOS-Simulator" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk appletvos -archivePath "${archiveDir}/tvOS" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk appletvsimulator -archivePath "${archiveDir}/tvOS-Simulator" $settings
xcodebuild clean archive -project BananaLib.xcodeproj -scheme "BananaLib" -sdk macosx -archivePath "${archiveDir}/macOS" $settings

archives=(iOS iOS-Simulator iOS-Catalyst watchOS watchOS-Simulator tvOS tvOS-Simulator macOS)

args=""
for archive in "${archives[@]}"; do
    args="$args -framework ${archiveDir}/${archive}.xcarchive/Products/Library/Frameworks/BananaLib.framework"
done

echo "Copying bitcode symbol maps..."
for archive in "${archives[@]}"; do
    symbolmap_src="${archiveDir}/${archive}.xcarchive/BCSymbolMaps"
    if [[ -d "$symbolmap_src" ]]; then
        rsync -av "${symbolmap_src}/" "${archiveDir}/${archive}.xcarchive/Products/Library/Frameworks/BananaLib.framework/BCSymbolMaps"
    else
        echo "No bitcode symbol maps in archive ${archive}"
    fi
done


echo "xcodebuild -create-xcframework $args -output build/BananaLib.xcframework"
xcodebuild -create-xcframework $args -output build/BananaLib.xcframework

echo "Gathering dSYMs to $DSYM_FOLDER..."
mkdir $DSYM_FOLDER
for archive in "${archives[@]}"; do
    dsym_src="${archiveDir}/${archive}.xcarchive/dSYMs/BananaLib.framework.dSYM"
    if [[ -d "$dsym_src" ]]; then
        rsync -av "${dsym_src}/" "${DSYM_FOLDER}/${archive}.dSYM"
    else
        echo "No dSYMs in archive ${archive}"
    fi
done
