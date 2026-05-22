#!/usr/bin/env bash
set -euo pipefail

# build-dmg.sh — pakuje podpisana Clank.app w DMG
#
# Uzycie: ./scripts/build-dmg.sh <Clank.app> <wyjsciowy.dmg>
#
# DMG zawiera: Clank.app + INSTALL.md + LICENSE + symlink /Applications.
# Aplikacja samodzielnie instaluje helpera sensora przy pierwszym uruchomieniu
# (przez NSAlert + macOS password prompt). Skrypty install/uninstall sa
# dostepne w repo do dev/diagnostyki, ale nie sa dystrybuowane w DMG.

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
