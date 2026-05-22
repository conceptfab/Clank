#!/usr/bin/env bash
set -euo pipefail

LABEL="dev.conceptfab.clank.sensor-helper"
DAEMON_PLIST="/Library/LaunchDaemons/${LABEL}.plist"
HELPER_BIN="/usr/local/libexec/clank-sensor-helper"

echo "==> Clank sensor helper - uninstall"
echo "The script will ask for your administrator password (sudo)."
echo ""

if sudo launchctl print "system/${LABEL}" >/dev/null 2>&1; then
    echo "==> Stopping daemon"
    sudo launchctl bootout "system/${LABEL}" || true
fi

if [[ -f "${DAEMON_PLIST}" ]]; then
    echo "==> Removing ${DAEMON_PLIST}"
    sudo rm -f "${DAEMON_PLIST}"
fi

if [[ -f "${HELPER_BIN}" ]]; then
    echo "==> Removing ${HELPER_BIN}"
    sudo rm -f "${HELPER_BIN}"
fi

sudo rm -f /tmp/clank-helper.events /tmp/clank-helper.heartbeat /var/log/clank-helper.log

echo ""
echo "Done. Helper uninstalled."
