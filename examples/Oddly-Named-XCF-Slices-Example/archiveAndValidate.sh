#!/usr/bin/env sh
#
# This script is executed by the ArchiveAndValidate target in the Xcode project.
# It will generate an archive build of the example project and then validate
# that the expected debug symbols (dSYMs and BCSymbolMaps) are present in the
# built archive. It will also validate that the symbols are not present in the
# embedded copy of the .frameworks.
#

exitCode=0

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

appPath="${archivePath}/Products/Applications/VendoredXCFrameworkExample.app"

if ! [[ "$(file -b "${appPath}/Frameworks/CoconutLib.framework/CoconutLib")" == *"arm64"* ]]; then
    echo "error: wrong arch: $(file -b "${appPath}/Frameworks/CoconutLib.framework/CoconutLib")"
    exitCode=1
fi

archivePath="${BUILD_DIR}/VendoredXCFrameworkExample-Simulator.xcarchive"

xcodebuild archive \
   -workspace "${PROJECT_DIR}/Examples.xcworkspace" \
   -scheme "VendoredXCFrameworkExample" \
   -configuration "Release" \
   -sdk iphonesimulator \
   -archivePath "${archivePath}" \
   CODE_SIGN_IDENTITY="" \
   CODE_SIGNING_REQUIRED=NO \
   CODE_SIGN_ENTITLEMENTS="" \
   CODE_SIGNING_ALLOWED="NO"

# ---------------------------------------
# Collecting debug symbols in archive
# ---------------------------------------

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

appPath="${archivePath}/Products/Applications/VendoredXCFrameworkExample.app"

if ! [[ "$(file -b "${appPath}/Frameworks/CoconutLib.framework/CoconutLib")" == *"x86_64"* ]]; then
    echo "error: wrong arch: $(file -b "${appPath}/Frameworks/CoconutLib.framework/CoconutLib")"
    exitCode=1
fi

exit $exitCode
