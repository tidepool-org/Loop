#!/bin/sh -e

#  capture-build-details.sh
#  Loop
#
#  Copyright © 2019 LoopKit Authors. All rights reserved.

SCRIPT="$(basename "${0}")"
SCRIPT_DIRECTORY="$(dirname "${0}")"

error() {
  echo "ERROR: ${*}" >&2
  echo "Usage: ${SCRIPT} [-r|--git-source-root git-source-root] [-p|--provisioning-profile-path provisioning-profile-path] [-i|--info-plist-path info-plist-path]" >&2
  echo "Parameters:" >&2
  echo "  -r|--git-source-root <git-source-root> root location of git repository to gather information from; optional, defaults to \$WORKSPACE_ROOT if present, otherwise defaults to \$SRCROOT" >&2
  echo "  -p|--provisioning-profile-path         path to the .mobileprovision provisioning profile file to check for expiration; optional, defaults to \${HOME}/Library/MobileDevice/Provisioning Profiles/\${EXPANDED_PROVISIONING_PROFILE}.mobileprovision" >&2
  echo "  -i|--info-plist-path                   path to the Info.plist file to modify; optional, defaults to \${BUILT_PRODUCTS_DIR}/\${INFOPLIST_PATH}" >&2
  exit 1
}

warn() {
  echo "WARN: ${*}" >&2
  exit 0
}

info() {
  echo "INFO: ${*}" >&2
}

git_source_root="${WORKSPACE_ROOT:-${SRCROOT}}"
plist="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
profile_path="${HOME}/Library/MobileDevice/Provisioning Profiles/${EXPANDED_PROVISIONING_PROFILE}.mobileprovision"
xcode_build_version=${XCODE_PRODUCT_BUILD_VERSION:-$(xcodebuild -version | grep version | cut -d ' ' -f 3)}
while [[ $# -gt 0 ]]
do
  arg="$1"

  case $arg in
    -r|--git-source-root)
      git_source_root="${2}"
      shift 2
      ;;
    -i|--info-plist-path)
      plist="${2}"
      shift 2
      ;;
    -p|--provisioning-profile-path)
      profile_path="${2}"
      shift 2
      ;;
  esac
done

if [ ${#} -ne 0 ]; then
  error "Unexpected arguments: ${*}"
fi

if [ "${git_source_root}" == "" ]; then
  error "Must provide one of --git-source-root, \$WORKSPACE_ROOT, or \$SRCROOT"
fi

info "Gathering build details in ${git_source_root}"
cd "${git_source_root}"

if [ -e .git ]; then
  rev=$(git rev-parse HEAD)
  plutil -replace com-loopkit-Loop-git-revision -string ${rev} "${plist}"
  branch=$(git branch --show-current)
  if [ "$branch" != "" ]; then
    plutil -replace com-loopkit-Loop-git-branch -string "${branch}" "${plist}"
  fi
fi;
plutil -replace com-loopkit-Loop-srcroot -string "${git_source_root}" "${plist}"
plutil -replace com-loopkit-Loop-build-date -string "$(date)" "${plist}"
plutil -replace com-loopkit-Loop-xcode-version -string "${xcode_build_version}" "${plist}"

if [ -e "${profile_path}" ]; then
  profile_expire_date=$(security cms -D -i "${profile_path}" | plutil -p - | grep ExpirationDate | cut -b 23-)
  # Convert to plutil format
  profile_expire_date=$(date -j -f "%Y-%m-%d %H:%M:%S" "${profile_expire_date}" +"%Y-%m-%dT%H:%M:%SZ")
  plutil -replace com-loopkit-Loop-profile-expiration -date "${profile_expire_date}" "${plist}"
fi;
