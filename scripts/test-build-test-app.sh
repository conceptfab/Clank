#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/scripts/build-test-app.sh"

if [[ ! -x "${SCRIPT}" ]]; then
    echo "error: ${SCRIPT} is missing or not executable" >&2
    exit 1
fi

output="$("${SCRIPT}" --dry-run)"

required=(
    "swift build -c debug"
    "build/test/Clank.app"
    "Contents/MacOS/Clank"
    "Clank_Clank.bundle"
    "codesign --force --deep --sign -"
    "codesign --verify --deep --strict"
)

for needle in "${required[@]}"; do
    if [[ "${output}" != *"${needle}"* ]]; then
        echo "error: dry-run output missing: ${needle}" >&2
        exit 1
    fi
done

echo "OK"
