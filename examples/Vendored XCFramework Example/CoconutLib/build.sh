#!/usr/bin/env sh
#
# This will build and export `CoconutLib.xcframework` to `build/CoconutLib.xcframework` including all supported slices.
# Use the `--static` flag to build static frameworks instead.
#
# Note: You may need to open the project and add a development team for code signing.
#

set -eou pipefail

rm -rf build/*

static=0
library=0

linkage="dynamic"
packaging="frameworks"

settings="SKIP_INSTALL=NO"
for arg in "$@"
do
    case $arg in
        -s|--static)
        static=1
        settings="$settings MACH_O_TYPE=staticlib"
        linkage="static"
        shift
        ;;
        -l|--library|--libraries)
        library=1
        packaging="libraries"
        shift
        ;;
        -f|--framework|--frameworks)
        library=0
        packaging="frameworks"
        shift
        ;;
        -d|--dynamic)
        static=0
        linkage="dynamic"
        settings="$settings MACH_O_TYPE=mh_dylib"
        shift
        ;;
    esac
done


echo "Building $linkage $packaging"

suffix=""
if [[ $library == 1 ]]; then
    suffix="-Library"
fi

DSYM_FOLDER=build/CoconutLib.dSYMs

xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-iOS$suffix" -sdk iphoneos -archivePath "build/iOS" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-iOS$suffix" -sdk iphonesimulator -archivePath "build/iOS-Simulator" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-iOS$suffix" -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' -archivePath "build/iOS-Catalyst" SKIP_INSTALL=NO
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-watchOS$suffix" -sdk watchos -archivePath "build/watchOS" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-watchOS$suffix" -sdk watchsimulator -archivePath "build/watchOS-Simulator" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-tvOS$suffix" -sdk appletvos -archivePath "build/tvOS" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-tvOS$suffix" -sdk appletvsimulator -archivePath "build/tvOS-Simulator" $settings
xcodebuild clean archive -project CoconutLib.xcodeproj -scheme "CoconutLib-macOS$suffix" -sdk macosx -archivePath "build/macOS" $settings

archives=(iOS iOS-Simulator iOS-Catalyst watchOS watchOS-Simulator tvOS tvOS-Simulator macOS)

args=""
if [[ $library == 1 ]]; then
    for archive in "${archives[@]}"; do
        args="$args -library build/${archive}.xcarchive/Products/usr/local/lib/libCoconut.a -headers build/${archive}.xcarchive/Products/usr/local/include"
    done
else
    for archive in "${archives[@]}"; do
        args="$args -framework build/${archive}.xcarchive/Products/Library/Frameworks/CoconutLib.framework"
    done
fi

if [[ $static == 0 && $library == 0 ]]; then
    echo "Copying bitcode symbol maps..."
    for archive in "${archives[@]}"; do
        symbolmap_src="build/${archive}.xcarchive/BCSymbolMaps"
        if [[ -d "$symbolmap_src" ]]; then
            rsync -av "${symbolmap_src}/" "build/${archive}.xcarchive/Products/Library/Frameworks/CoconutLib.framework/BCSymbolMaps"
        else
            echo "No bitcode symbol maps in archive ${archive}"
        fi
    done
fi


echo "xcodebuild -create-xcframework $args -output build/CoconutLib.xcframework"
xcodebuild -create-xcframework $args -output build/CoconutLib.xcframework

if [[ $static == 0 ]]; then
    echo "Gathering dSYMs to $DSYM_FOLDER..."
    mkdir $DSYM_FOLDER
    for archive in "${archives[@]}"; do
        dsym_src="build/${archive}.xcarchive/dSYMs/CoconutLib.framework.dSYM"
        if [[ -d "$dsym_src" ]]; then
            rsync -av "${dsym_src}/" "${DSYM_FOLDER}/${archive}.dSYM"
        else
            echo "No dSYMs in archive ${archive}"
        fi
    done
else
    echo "Skipping dSYM collection because static binaries do not produce dSYMs"
fi
echo "Done."
