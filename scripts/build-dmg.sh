#!/usr/bin/env bash
set -euo pipefail

# build-dmg.sh — pakuje Clank.app w DMG razem ze skryptami instalacyjnymi
#
# Uzycie: ./scripts/build-dmg.sh <Clank.app> <wyjsciowy.dmg>

APP_PATH="${1:?usage: build-dmg.sh <Clank.app> <output.dmg>}"
OUT_DMG="${2:?usage: build-dmg.sh <Clank.app> <output.dmg>}"

if [[ ! -d "${APP_PATH}" ]]; then
    echo "blad: nie znaleziono ${APP_PATH}" >&2
    exit 1
fi

OUT_DIR="$(dirname "${OUT_DMG}")"
mkdir -p "${OUT_DIR}"

STAGE="$(mktemp -d -t clank-dmg.XXXXXX)"
trap 'rm -rf "${STAGE}"' EXIT

echo "==> Przygotowuje zawartosc DMG w ${STAGE}"
cp -R "${APP_PATH}" "${STAGE}/Clank.app"
cp INSTALL.md "${STAGE}/INSTALL.md"
cp LICENSE "${STAGE}/LICENSE"
mkdir -p "${STAGE}/scripts"
cp scripts/install-helper.sh "${STAGE}/scripts/"
cp scripts/uninstall-helper.sh "${STAGE}/scripts/"
chmod +x "${STAGE}/scripts/"*.sh

# Symlink do /Applications dla ladnego drag-to-install UX
ln -s /Applications "${STAGE}/Applications"

echo "==> Tworze DMG: ${OUT_DMG}"
rm -f "${OUT_DMG}"
hdiutil create \
    -volname "Clank" \
    -srcfolder "${STAGE}" \
    -ov \
    -format UDZO \
    "${OUT_DMG}"

echo ""
echo "Gotowe: ${OUT_DMG}"
ls -lh "${OUT_DMG}"
