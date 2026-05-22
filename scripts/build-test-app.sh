#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Clank"
EXECUTABLE="Clank"
CONFIGURATION="debug"
BUILD_ROOT="${ROOT}/build/test"
APP_DIR="${BUILD_ROOT}/${APP_NAME}.app"
ENTITLEMENTS="${ROOT}/Clank.entitlements"
DRY_RUN=0
CLEAN=1

usage() {
    cat <<EOF
Usage: $0 [options]

Build a local testable Clank.app bundle.

Options:
  --configuration <debug|release>  SwiftPM configuration (default: debug)
  --output <path>                  Output .app path (default: build/test/Clank.app)
  --no-clean                       Do not remove the existing output app first
  --dry-run                        Print the build steps without running them
  -h, --help                       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configuration)
            CONFIGURATION="${2:?missing value for --configuration}"
            shift 2
            ;;
        --output)
            APP_DIR="$2"
            shift 2
            ;;
        --no-clean)
            CLEAN=0
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "${CONFIGURATION}" != "debug" && "${CONFIGURATION}" != "release" ]]; then
    echo "error: --configuration must be debug or release" >&2
    exit 1
fi

case "${APP_DIR}" in
    /*) ;;
    *) APP_DIR="${ROOT}/${APP_DIR}" ;;
esac

APP_PARENT="$(dirname "${APP_DIR}")"
EXECUTABLE_PATH="${ROOT}/.build/${CONFIGURATION}/${EXECUTABLE}"
RESOURCES_BUNDLE="${ROOT}/.build/${CONFIGURATION}/Clank_Clank.bundle"
APP_EXECUTABLE="${APP_DIR}/Contents/MacOS/${EXECUTABLE}"
APP_RESOURCES="${APP_DIR}/Contents/Resources"

run_step() {
    local label="$1"
    shift
    echo "==> ${label}"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "+ $*"
    else
        "$@"
    fi
}

copy_if_exists() {
    local source="$1"
    local destination="$2"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "+ cp -R ${source} ${destination}"
        return
    fi
    if [[ -e "${source}" ]]; then
        cp -R "${source}" "${destination}"
    fi
}

echo "Test app:      ${APP_DIR}"
echo "Configuration: ${CONFIGURATION}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "(dry run - no files will be changed)"
fi
echo

run_step "SwiftPM build" swift build -c "${CONFIGURATION}"

if [[ "${CLEAN}" -eq 1 ]]; then
    run_step "Remove previous app bundle" rm -rf "${APP_DIR}"
fi

run_step "Create app bundle directories" mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_RESOURCES}"
run_step "Copy executable" cp "${EXECUTABLE_PATH}" "${APP_EXECUTABLE}"
run_step "Copy Info.plist" cp "${ROOT}/Info.plist" "${APP_DIR}/Contents/Info.plist"
run_step "Copy app icon" cp "${ROOT}/Sources/Clank/Resources/AppIcon.icns" "${APP_RESOURCES}/AppIcon.icns"
copy_if_exists "${RESOURCES_BUNDLE}" "${APP_RESOURCES}/"
run_step "Mark executable" chmod +x "${APP_EXECUTABLE}"

run_step "Clear extended attributes" xattr -cr "${APP_DIR}"
run_step "Ad-hoc sign app" codesign --force --deep --sign - --entitlements "${ENTITLEMENTS}" "${APP_DIR}"
run_step "Verify signature" codesign --verify --deep --strict "${APP_DIR}"

echo
echo "Done. Test app is ready:"
echo "  ${APP_DIR}"
echo
echo "Run it with:"
echo "  open ${APP_DIR}"
