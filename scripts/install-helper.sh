#!/usr/bin/env bash
set -euo pipefail

# install-helper.sh — installs the Clank sensor LaunchDaemon
#
# Usage: ./scripts/install-helper.sh /path/to/Clank.app
# If no path is given, the script looks in standard application locations.

LABEL="dev.conceptfab.clank.sensor-helper"
DAEMON_PLIST="/Library/LaunchDaemons/${LABEL}.plist"
HELPER_BIN="/usr/local/libexec/clank-sensor-helper"

usage() {
    cat <<EOF
Usage: $0 [/path/to/Clank.app]

This script will install the Clank sensor helper LaunchDaemon.
You will need to enter your administrator password once.

After installation, the helper will start automatically and Clank.app
will be able to use it without sudo.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

APP_PATH="${1:-}"
if [[ -z "${APP_PATH}" ]]; then
    for candidate in \
        "/Applications/Clank.app" \
        "${HOME}/Applications/Clank.app" \
        "$(cd "$(dirname "$0")/.." && pwd)/build/Clank.app"; do
        if [[ -d "${candidate}" ]]; then
            APP_PATH="${candidate}"
            break
        fi
    done
fi

if [[ ! -d "${APP_PATH}" ]]; then
    echo "error: Clank.app not found - pass the path as an argument" >&2
    exit 1
fi

SRC_BIN="${APP_PATH}/Contents/MacOS/Clank"
SRC_TEMPLATE="$(find "${APP_PATH}" -name 'dev.conceptfab.clank.sensor-helper.plist.template' -type f -print -quit 2>/dev/null || true)"

if [[ ! -f "${SRC_BIN}" ]]; then
    echo "error: missing binary at ${SRC_BIN}" >&2
    exit 1
fi
if [[ ! -f "${SRC_TEMPLATE}" ]]; then
    echo "error: plist template not found in the app bundle" >&2
    exit 1
fi

echo "==> Clank sensor helper - installation"
echo "    app:        ${APP_PATH}"
echo "    helper bin:  ${HELPER_BIN}"
echo "    daemon plist: ${DAEMON_PLIST}"
echo ""
echo "The script will ask for your administrator password (sudo) once."
echo ""

# Generate plist with the resolved helper path.
TMP_PLIST="$(mktemp -t clank-helper.plist.XXXXXX)"
trap 'rm -f "${TMP_PLIST}"' EXIT
sed "s|__HELPER_BINARY__|${HELPER_BIN}|g" "${SRC_TEMPLATE}" > "${TMP_PLIST}"

# Validate the generated plist.
plutil -lint "${TMP_PLIST}" >/dev/null

# If the daemon already runs, unload it before replacing files.
if sudo launchctl print "system/${LABEL}" >/dev/null 2>&1; then
    echo "==> Stopping existing daemon"
    sudo launchctl bootout "system/${LABEL}" || true
fi

echo "==> Copying helper binary to ${HELPER_BIN}"
sudo mkdir -p /usr/local/libexec
sudo cp "${SRC_BIN}" "${HELPER_BIN}"
sudo chown root:wheel "${HELPER_BIN}"
sudo chmod 755 "${HELPER_BIN}"

echo "==> Installing plist at ${DAEMON_PLIST}"
sudo cp "${TMP_PLIST}" "${DAEMON_PLIST}"
sudo chown root:wheel "${DAEMON_PLIST}"
sudo chmod 644 "${DAEMON_PLIST}"

echo "==> Loading daemon"
sudo launchctl bootstrap system "${DAEMON_PLIST}"
sudo launchctl enable "system/${LABEL}"

echo ""
echo "Done. The helper is running as a system daemon."
echo "Check:      sudo launchctl print system/${LABEL} | head -20"
echo "Logs:       tail -f /var/log/clank-helper.log"
echo "Uninstall:  ./scripts/uninstall-helper.sh"
