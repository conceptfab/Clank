#!/usr/bin/env bash
set -euo pipefail

LABEL="dev.conceptfab.clank.sensor-helper"
DAEMON_PLIST="/Library/LaunchDaemons/${LABEL}.plist"
HELPER_BIN="/usr/local/libexec/clank-sensor-helper"

echo "==> Clank sensor helper — odinstalowanie"
echo "Skrypt poprosi o haslo administratora (sudo)."
echo ""

if sudo launchctl print "system/${LABEL}" >/dev/null 2>&1; then
    echo "==> Wylaczam daemon"
    sudo launchctl bootout "system/${LABEL}" || true
fi

if [[ -f "${DAEMON_PLIST}" ]]; then
    echo "==> Usuwam ${DAEMON_PLIST}"
    sudo rm -f "${DAEMON_PLIST}"
fi

if [[ -f "${HELPER_BIN}" ]]; then
    echo "==> Usuwam ${HELPER_BIN}"
    sudo rm -f "${HELPER_BIN}"
fi

sudo rm -f /tmp/clank-helper.events /tmp/clank-helper.heartbeat /var/log/clank-helper.log

echo ""
echo "Gotowe. Helper odinstalowany."
