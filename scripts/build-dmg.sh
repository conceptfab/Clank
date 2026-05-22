#!/usr/bin/env bash
set -euo pipefail

# build-dmg.sh — packages a signed Clank.app into a DMG
#
# Usage: ./scripts/build-dmg.sh <Clank.app> <output.dmg>
#
# The DMG includes: Clank.app + INSTALL.md + LICENSE + /Applications symlink.
# The app installs the sensor helper on first launch
# through NSAlert + the macOS password prompt. The install/uninstall scripts
# are kept in the repo for development/diagnostics, but are not distributed in the DMG.

APP_PATH="${1:?usage: build-dmg.sh <Clank.app> <output.dmg>}"
OUT_DMG="${2:?usage: build-dmg.sh <Clank.app> <output.dmg>}"

if [[ ! -d "${APP_PATH}" ]]; then
    echo "error: ${APP_PATH} not found" >&2
    exit 1
fi

OUT_DIR="$(dirname "${OUT_DMG}")"
mkdir -p "${OUT_DIR}"

STAGE="$(mktemp -d -t clank-dmg.XXXXXX)"
trap 'rm -rf "${STAGE}"' EXIT

echo "==> Preparing DMG contents in ${STAGE}"
cp -R "${APP_PATH}" "${STAGE}/Clank.app"
cp INSTALL.md "${STAGE}/INSTALL.md"
cp LICENSE "${STAGE}/LICENSE"

# /Applications symlink for the drag-to-install flow.
ln -s /Applications "${STAGE}/Applications"

echo "==> Creating DMG: ${OUT_DMG}"
rm -f "${OUT_DMG}"
hdiutil create \
    -volname "Clank" \
    -srcfolder "${STAGE}" \
    -ov \
    -format UDZO \
    "${OUT_DMG}"

echo ""
echo "Done: ${OUT_DMG}"
ls -lh "${OUT_DMG}"
