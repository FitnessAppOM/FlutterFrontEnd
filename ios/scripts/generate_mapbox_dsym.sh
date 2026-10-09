#!/bin/sh

# MapboxCommon is distributed as a precompiled framework without a dSYM in
# some Mapbox SDK releases. Generate the matching UUID bundle from the embedded
# binary so App Store Connect can process symbols without rejecting the upload.
set -eu

if [ "${PLATFORM_NAME:-}" != "iphoneos" ]; then
  exit 0
fi

case "${CONFIGURATION:-}" in
  Release|Profile) ;;
  *) exit 0 ;;
esac

framework_binary="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/MapboxCommon.framework/MapboxCommon"
dsym_path="${DWARF_DSYM_FOLDER_PATH}/MapboxCommon.framework.dSYM"
dsym_binary="${dsym_path}/Contents/Resources/DWARF/MapboxCommon"

if [ ! -f "${framework_binary}" ] || [ -s "${dsym_binary}" ]; then
  exit 0
fi

echo "Generating MapboxCommon.framework.dSYM"
"$(xcrun --find dsymutil)" "${framework_binary}" -o "${dsym_path}"
