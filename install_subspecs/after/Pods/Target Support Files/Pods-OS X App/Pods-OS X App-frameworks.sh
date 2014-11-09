#!/bin/sh
set -e

echo "mkdir -p ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

install_framework()
{
  echo "rsync --exclude '*.h' -av ${PODS_ROOT}/$1 ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
  rsync -av "${BUILT_PRODUCTS_DIR}/Pods-OS X App/$1" "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
}

if [[ "$CONFIGURATION" == "Debug" ]]; then
  install_framework 'PodTest.framework'
fi
if [[ "$CONFIGURATION" == "Release" ]]; then
  install_framework 'PodTest.framework'
fi
