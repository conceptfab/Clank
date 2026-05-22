#!/usr/bin/env bash
# Deploys page/ to the FTP server defined in .env_ftp.
#
# .env_ftp format (shell-style keys are preferred):
#   FTP_HOST = host372606.hostido.net.pl
#   FTP_USER = admin@example.com
#   FTP_PASS = "password"
#   FTP_DIR = "/public_html/clank"
#
# Legacy Polish labels are also accepted:
#   Logowanie:   <user>
#   Hasło:       <password>
#   Ścieżka:     <absolute server path, informational>
#
# Optional extra lines (added by this script's convention):
#   Host:        <ftp host>      # defaults to ftp.conceptfab.com
#   Katalog:     <remote dir>    # defaults to / (FTP login is usually chrooted)
#
# Usage:
#   scripts/deploy-page.sh                # upload everything
#   scripts/deploy-page.sh --dry-run      # list what would be uploaded
#   HOST=ftp.example.com scripts/deploy-page.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env_ftp"
LOCAL_DIR="${REPO_ROOT}/page"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: $ENV_FILE not found" >&2
  exit 1
fi

if [[ ! -d "$LOCAL_DIR" ]]; then
  echo "error: $LOCAL_DIR not found" >&2
  exit 1
fi

# Parse label/value lines (tab- or whitespace-separated). Strip CR for safety.
parse_field() {
  local label="$1"
  awk -v L="$label" '
    BEGIN { IGNORECASE = 1 }
    {
      sub(/\r$/, "")
      if (index($0, L) == 1) {
        sub("^" L "[[:space:]]*", "")
        print
        exit
      }
    }
  ' "$ENV_FILE"
}

parse_assignment() {
  local key="$1"
  awk -v K="$key" '
    {
      sub(/\r$/, "")
      line = $0
      sub(/^[[:space:]]*/, "", line)
      if (line ~ "^" K "[[:space:]]*=") {
        sub("^" K "[[:space:]]*=[[:space:]]*", "", line)
        if (substr(line, 1, 1) == "\"" && substr(line, length(line), 1) == "\"") {
          line = substr(line, 2, length(line) - 2)
        }
        if (substr(line, 1, 1) == sprintf("%c", 39) && substr(line, length(line), 1) == sprintf("%c", 39)) {
          line = substr(line, 2, length(line) - 2)
        }
        print line
        exit
      }
    }
  ' "$ENV_FILE"
}

FTP_USER="$(parse_field 'Logowanie:')"
[[ -z "$FTP_USER" ]] && FTP_USER="$(parse_assignment 'FTP_USER')"
FTP_PASS="$(parse_field 'Hasło:')"
[[ -z "$FTP_PASS" ]] && FTP_PASS="$(parse_assignment 'FTP_PASS')"
FTP_HOST="${HOST:-$(parse_field 'Host:')}"
[[ -z "$FTP_HOST" ]] && FTP_HOST="$(parse_assignment 'FTP_HOST')"
REMOTE_DIR="${REMOTE_DIR:-$(parse_field 'Katalog:')}"
[[ -z "$REMOTE_DIR" ]] && REMOTE_DIR="$(parse_assignment 'FTP_DIR')"

: "${FTP_HOST:=conceptfab.com}"
: "${REMOTE_DIR:=/}"

# Normalise REMOTE_DIR: ensure leading slash, strip trailing slash (unless root).
[[ "$REMOTE_DIR" != /* ]] && REMOTE_DIR="/$REMOTE_DIR"
[[ "$REMOTE_DIR" != "/" ]] && REMOTE_DIR="${REMOTE_DIR%/}"

if [[ -z "$FTP_USER" || -z "$FTP_PASS" ]]; then
  echo "error: could not parse FTP_USER/FTP_PASS from $ENV_FILE" >&2
  exit 1
fi

DRY_RUN=0
DEBUG=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --debug)   DEBUG=1 ;;
  esac
done

# FTPS modes: "off" (plain), "try" (opportunistic STARTTLS), "reqd" (require AUTH TLS).
# Default to "reqd" — conceptfab.com (ProFTPD on hostido/IQ.PL) supports AUTH SSL and
# we don't want passwords flying in clear if a future server happens to allow plain.
TLS_MODE="${TLS_MODE:-reqd}"
case "$TLS_MODE" in
  off|try|reqd) ;;
  *) echo "error: TLS_MODE must be off|try|reqd (got: $TLS_MODE)" >&2; exit 1 ;;
esac

curl_tls_args=()
case "$TLS_MODE" in
  try)  curl_tls_args+=(--ssl) ;;
  reqd) curl_tls_args+=(--ssl-reqd) ;;
esac

echo "Deploy target: ftp(${TLS_MODE})://${FTP_USER}  @  ${FTP_HOST}${REMOTE_DIR}"
echo "Source dir:    ${LOCAL_DIR}"
[[ $DRY_RUN -eq 1 ]] && echo "(dry run - no files will be uploaded)"
echo

# Verbose log file with the password redacted, for --debug only.
DEBUG_LOG=""
if [[ $DEBUG -eq 1 ]]; then
  DEBUG_LOG="$(mktemp -t deploy-page-debug.XXXXXX.log)"
  echo "(debug log: $DEBUG_LOG — password redacted)"
  echo
fi

redact_log() {
  # Strip the password from any line before showing/saving it.
  local pw="$1"; shift
  sed -e "s|${pw}|***REDACTED***|g"
}

# Build file list, sorted, NUL-safe.
files=()
while IFS= read -r -d '' f; do
  files+=("$f")
done < <(cd "$LOCAL_DIR" && find . -type f \! -name '.DS_Store' -print0 | sort -z)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "no files to upload" >&2
  exit 0
fi

ok=0
fail=0
for rel in "${files[@]}"; do
  rel="${rel#./}"
  local_path="${LOCAL_DIR}/${rel}"
  if [[ "$REMOTE_DIR" == "/" ]]; then
    remote_url="ftp://${FTP_HOST}/${rel}"
  else
    remote_url="ftp://${FTP_HOST}${REMOTE_DIR}/${rel}"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  would upload  %s  ->  %s\n' "$rel" "$remote_url"
    continue
  fi

  printf '  uploading     %s ... ' "$rel"
  curl_args=(--silent --show-error --fail --ftp-create-dirs
             --user "${FTP_USER}:${FTP_PASS}"
             --upload-file "$local_path"
             "${curl_tls_args[@]}"
             "$remote_url")
  if [[ $DEBUG -eq 1 ]]; then
    {
      echo "=== $rel ==="
      curl --verbose "${curl_args[@]}" 2>&1
      echo
    } | redact_log "$FTP_PASS" >> "$DEBUG_LOG"
    rc=${PIPESTATUS[0]}
  else
    curl_err=$(curl "${curl_args[@]}" 2>&1)
    rc=$?
  fi
  if [[ $rc -eq 0 ]]; then
    echo "ok"
    ok=$((ok + 1))
  else
    echo "FAILED"
    [[ $DEBUG -eq 0 && -n "${curl_err:-}" ]] && echo "    $(echo "$curl_err" | redact_log "$FTP_PASS" | tail -1)"
    fail=$((fail + 1))
  fi
done

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "dry run complete (${#files[@]} files)"
  exit 0
fi

echo "uploaded: ${ok}  failed: ${fail}  total: ${#files[@]}"
if [[ $fail -gt 0 ]]; then
  exit 1
fi
