#!/bin/sh

#  copy-plugins.sh
#  Loop
#
#  Copyright © 2019 LoopKit Authors. All rights reserved.

echo "Looking for plugins in $BUILT_PRODUCTS_DIR"

shopt -s nullglob

# Copy device plugins
for f in ${BUILT_PRODUCTS_DIR}/*.loopplugin; do
  plugin=$(basename $f)
  echo Copying device plugin: $plugin to plugins directory in app
  cp -a $f ${BUILT_PRODUCTS_DIR}/${PLUGINS_FOLDER_PATH}
  if [ "$EXPANDED_CODE_SIGN_IDENTITY" != "-" ]; then
    export CODESIGN_ALLOCATE=${DT_TOOLCHAIN_DIR}/usr/bin/codesign_allocate
    destination=${BUILT_PRODUCTS_DIR}/${PLUGINS_FOLDER_PATH}/${plugin}
    echo "Signing ${plugin} with ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
    /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --timestamp=none --preserve-metadata=identifier,entitlements,flags ${destination}
    for framework_path in ${destination}/Frameworks/*.framework; do
      framework=$(basename $framework_path)
      echo "Signing $framework for $plugin with $EXPANDED_CODE_SIGN_IDENTITY_NAME"
      /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --timestamp=none --preserve-metadata=identifier,entitlements,flags ${framework_path}
    done
  else
    echo "Skipping signing of ${plugin}"
  fi
done

