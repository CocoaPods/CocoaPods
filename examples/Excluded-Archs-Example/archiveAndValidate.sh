#!/usr/bin/env sh
#
# This script is executed by the ArchiveAndValidate target in the Xcode project.
# It will generate an archive build of the example project and then validate
# that the expected debug symbols (dSYMs and BCSymbolMaps) are present in the
# built archive. It will also validate that the symbols are not present in the
# embedded copy of the .frameworks.
#

archivePath="${BUILD_DIR}/VendoredXCFrameworkExample.xcarchive"

xcodebuild archive \
   -workspace "${PROJECT_DIR}/Examples.xcworkspace" \
   -scheme "VendoredXCFrameworkExample" \
   -configuration "Release" \
   -archivePath "${archivePath}" \
   CODE_SIGN_IDENTITY="" \
   CODE_SIGNING_REQUIRED=NO \
   CODE_SIGN_ENTITLEMENTS="" \
   CODE_SIGNING_ALLOWED="NO"

# ---------------------------------------
# Collecting debug symbols in archive
# ---------------------------------------
exitCode=0

bcSymbolMapsPath="${archivePath}/BCSymbolMaps"

# Ensure the expected Xcode 12-style CoconutLib BCSymbolMaps are in the root of the archive
libraryBCSymbolMapDir="${PROJECT_DIR}/CoconutLib/build/CoconutLib.xcframework/ios-arm64/BCSymbolMaps"
for file in "${libraryBCSymbolMapDir}"/*; do
    filename="${file##*/}"
    if ! test -f "${bcSymbolMapsPath}/${filename}"; then
        echo "error: Missing BCSymbolMap for CoconutLib: ${filename}"
        exitCode=1
    fi
done

# Ensure the expected dSYMs are in the root of the archive
dsymsPath="${archivePath}/dSYMs"

if ! test -d "$dsymsPath/VendoredXCFrameworkExample.app.dSYM"; then
    echo "error: Missing dSYM: VendoredXCFrameworkExample.app.dSYM"
    exitCode=1
fi

if ! test -d "$dsymsPath/CoconutLib.framework.dSYM"; then
    echo "error: Missing dSYM: CoconutLib.framework.dSYM"
    exitCode=1
fi

exit $exitCode
