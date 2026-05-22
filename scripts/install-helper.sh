#!/usr/bin/env bash
set -euo pipefail

# install-helper.sh — instaluje Clank sensor LaunchDaemon
#
# Wywolanie: ./scripts/install-helper.sh /sciezka/do/Clank.app
# Jezeli sciezka nie podana, skrypt szuka aplikacji w standardowych lokalizacjach.

LABEL="dev.conceptfab.clank.sensor-helper"
DAEMON_PLIST="/Library/LaunchDaemons/${LABEL}.plist"
HELPER_BIN="/usr/local/libexec/clank-sensor-helper"

usage() {
    cat <<EOF
Uzycie: $0 [/sciezka/do/Clank.app]

Skrypt zainstaluje LaunchDaemon helpera sensora Clank.
Wymagane jest jednorazowe podanie hasla administratora.

Po instalacji helper bedzie startowal automatycznie i Clank.app
bedzie mogla go uzywac bez sudo.
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
    echo "blad: nie znaleziono Clank.app — podaj sciezke jako argument" >&2
    exit 1
fi

SRC_BIN="${APP_PATH}/Contents/MacOS/Clank"
SRC_TEMPLATE="$(find "${APP_PATH}" -name 'dev.conceptfab.clank.sensor-helper.plist.template' -type f -print -quit 2>/dev/null || true)"

if [[ ! -f "${SRC_BIN}" ]]; then
    echo "blad: brak binarki w ${SRC_BIN}" >&2
    exit 1
fi
if [[ ! -f "${SRC_TEMPLATE}" ]]; then
    echo "blad: nie znaleziono pliku plist template w bundle aplikacji" >&2
    exit 1
fi

echo "==> Clank sensor helper — instalacja"
echo "    aplikacja:   ${APP_PATH}"
echo "    helper bin:  ${HELPER_BIN}"
echo "    daemon plist: ${DAEMON_PLIST}"
echo ""
echo "Skrypt poprosi o haslo administratora (sudo) — JEDNORAZOWO."
echo ""

# Generuj plist z podstawiona sciezka
TMP_PLIST="$(mktemp -t clank-helper.plist.XXXXXX)"
trap 'rm -f "${TMP_PLIST}"' EXIT
sed "s|__HELPER_BINARY__|${HELPER_BIN}|g" "${SRC_TEMPLATE}" > "${TMP_PLIST}"

# Walidacja wygenerowanego plist
plutil -lint "${TMP_PLIST}" >/dev/null

# Jezeli daemon juz dziala, unload przed wymiana
if sudo launchctl print "system/${LABEL}" >/dev/null 2>&1; then
    echo "==> Wylaczam istniejacy daemon"
    sudo launchctl bootout "system/${LABEL}" || true
fi

echo "==> Kopiuje binarke helpera do ${HELPER_BIN}"
sudo mkdir -p /usr/local/libexec
sudo cp "${SRC_BIN}" "${HELPER_BIN}"
sudo chown root:wheel "${HELPER_BIN}"
sudo chmod 755 "${HELPER_BIN}"

echo "==> Instaluje plist w ${DAEMON_PLIST}"
sudo cp "${TMP_PLIST}" "${DAEMON_PLIST}"
sudo chown root:wheel "${DAEMON_PLIST}"
sudo chmod 644 "${DAEMON_PLIST}"

echo "==> Laduje daemon"
sudo launchctl bootstrap system "${DAEMON_PLIST}"
sudo launchctl enable "system/${LABEL}"

echo ""
echo "Gotowe. Helper dziala jako system daemon."
echo "Sprawdzenie:  sudo launchctl print system/${LABEL} | head -20"
echo "Logi:         tail -f /var/log/clank-helper.log"
echo "Odinstalowanie: ./scripts/uninstall-helper.sh"
