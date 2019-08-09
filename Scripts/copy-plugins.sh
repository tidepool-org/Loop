#!/bin/sh

#  copy-plugins.sh
#  Loop
#
#  Copyright © 2019 LoopKit Authors. All rights reserved.

echo "Looking for plugins in $BUILT_PRODUCTS_DIR"

shopt -s nullglob

# Copy device plugins
for f in "${BUILT_PRODUCTS_DIR}"/*.loopplugin; do
  plugin=$(basename "$f")
  echo Copying device plugin: $plugin to frameworks directory in app
  plugin_path="$(readlink "$f" || echo "$f")"
  rsync -va --exclude=Frameworks "$plugin_path" "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
  plugin_basename=$(basename "$f")
  # Rename .plugin to .framework
  plugin_as_framework_path="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/${plugin_basename%.*}.framework"
  echo moving "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/${plugin_basename}" to "$plugin_as_framework_path"
  mv "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/${plugin_basename}" "$plugin_as_framework_path"
  cp -a "$f/Frameworks/" "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
  if [ "$EXPANDED_CODE_SIGN_IDENTITY" != "-" ]; then
    export CODESIGN_ALLOCATE=${DT_TOOLCHAIN_DIR}/usr/bin/codesign_allocate
    echo "Signing ${plugin} with ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
    /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --timestamp=none --preserve-metadata=identifier,entitlements,flags "$plugin_as_framework_path"
    echo "Signing plugin's frameworks in "${f}"/Frameworks/*.framework"
    for framework_path in "${f}"/Frameworks/*.framework; do
      framework=$(basename "$framework_path")
      echo "Signing $framework for $plugin with $EXPANDED_CODE_SIGN_IDENTITY_NAME"
      /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --timestamp=none --preserve-metadata=identifier,entitlements,flags "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/${framework}"
    done
  else
    echo "Skipping signing of ${plugin}"
  fi
done

