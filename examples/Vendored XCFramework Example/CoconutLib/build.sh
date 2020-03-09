#!/usr/bin/env sh
#
# This will build and export `CoconutLib.xcframework` to `build/CoconutLib.xcframework` including all supported slices.
# Use the `--static` flag to build static frameworks instead.
#
# Note: You may need to open the project and add a development team for code signing.
#

set -eou pipefail

rm -rf build/*

settings="SKIP_INSTALL=NO"
if [[ ! -z ${1+x} && "$1" == "--static" ]]; then
	settings="$settings MACH_O_TYPE=staticlib"
	echo "Building static frameworks"
else
	echo "Building dynamic frameworks"
fi

DSYM_FOLDER=build/CoconutLib.dSYMs

xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-iOS" -sdk iphoneos -archivePath "build/iOS" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-iOS" -sdk iphonesimulator -archivePath "build/iOS-Simulator" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-iOS" -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' -archivePath "build/iOS-Catalyst" SKIP_INSTALL=NO
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-watchOS" -sdk watchos -archivePath "build/watchOS" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-watchOS" -sdk watchsimulator -archivePath "build/watchOS-Simulator" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-tvOS" -sdk appletvos -archivePath "build/tvOS" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-tvOS" -sdk appletvsimulator -archivePath "build/tvOS-Simulator" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-macOS" -sdk macosx -archivePath "build/macOS" $settings

archives=(iOS iOS-Simulator iOS-Catalyst watchOS watchOS-Simulator tvOS tvOS-Simulator macOS)
frameworks=""
dSYMs=""
for archive in "${archives[@]}"; do
	frameworks="$frameworks -framework build/${archive}.xcarchive/Products/Library/Frameworks/CoconutLib.framework"
	dSYMs="$dSYMs ${archive}.xcarchive/dSYMs/"
done

echo "xcodebuild -create-xcframework $frameworks -output build/CoconutLib.xcframework"
xcodebuild -create-xcframework $frameworks -output build/CoconutLib.xcframework

echo "Gathering dSYMs to $DSYM_FOLDER..."
mkdir $DSYM_FOLDER
for archive in "${archives[@]}"; do
	dsym_src="build/${archive}.xcarchive/dSYMs/CoconutLib.framework.dSYM"
	if [[ -d "$dsym_src" ]]; then
		# mkdir "${DSYM_FOLDER}/${archive}.dSYM"
		rsync -av "${dsym_src}/" "${DSYM_FOLDER}/${archive}.dSYM"
	else
		echo "No dSYMs in archive ${archive}"
	fi
done
echo "Done."
