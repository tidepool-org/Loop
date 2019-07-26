#!/bin/sh

#  copy-plugins.sh
#  Loop
#
#  Copyright © 2019 LoopKit Authors. All rights reserved.

#export EXPANDED_CODE_SIGN_IDENTITY=E7B3EE0414C12AAEF30B0B6F548A4631607843EA
#export DT_TOOLCHAIN_DIR=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain
#export BUILT_PRODUCTS_DIR="/Users/pete/Library/Developer/Xcode/DerivedData/Loop-brxfloqwyetegifggkanxcujdfuf/Build/Intermediates.noindex/ArchiveIntermediates/Loop (Workspace)/BuildProductsPath/Release-iphoneos"
#export EXPANDED_CODE_SIGN_IDENTITY_NAME="iPhone Developer: Pete Schwamb (KX4XY883PR)"
#export PLUGINS_FOLDER_PATH=Loop.app/PlugIns

echo "Looking for plugins in $BUILT_PRODUCTS_DIR"

shopt -s nullglob

# Copy device plugins
for f in "${BUILT_PRODUCTS_DIR}"/*.loopplugin; do
  plugin=$(basename "$f")
  echo Copying device plugin: $plugin to plugins directory in app
  
  # Dereference symlinks if needed
  plugin_path="$(readlink "$f" || echo "$f")"
  cp -a "$plugin_path" "${BUILT_PRODUCTS_DIR}/${PLUGINS_FOLDER_PATH}"
  echo "Copied"
  if [ "$EXPANDED_CODE_SIGN_IDENTITY" != "-" ]; then
    export CODESIGN_ALLOCATE=${DT_TOOLCHAIN_DIR}/usr/bin/codesign_allocate
    destination="${BUILT_PRODUCTS_DIR}/${PLUGINS_FOLDER_PATH}/${plugin}"
    echo "Signing ${plugin} with ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
    echo "destination = $destination"
    /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --timestamp=none --preserve-metadata=identifier,entitlements,flags "$destination"
    for framework_path in "${destination}"/Frameworks/*.framework; do
      framework=$(basename "$framework_path")
      echo "Signing $framework for $plugin with $EXPANDED_CODE_SIGN_IDENTITY_NAME"
      /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --timestamp=none --preserve-metadata=identifier,entitlements,flags "$framework_path"
    done
  else
    echo "Skipping signing of ${plugin}"
  fi
done

