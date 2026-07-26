#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$REPO_ROOT/vendor/Ghostship"
UPSTREAM_URL="https://github.com/HarbourMasters/Ghostship.git"
PIN="49c5312a0f3c0a28e1974be1923babd4f869f719"   # develop, 2026-07-16 (D13 bump; was 37b77e30 2026-06-23)

if [ -d "$VENDOR/.git" ]; then
    CUR="$(git -C "$VENDOR" rev-parse HEAD)"
    if [ "$CUR" = "$PIN" ]; then
        echo "vendor/Ghostship already at pin $PIN"
    else
        echo "vendor/Ghostship at $CUR, re-pinning to $PIN"
        git -C "$VENDOR" fetch origin
        git -C "$VENDOR" checkout "$PIN"
    fi
else
    git clone "$UPSTREAM_URL" "$VENDOR"
    git -C "$VENDOR" checkout "$PIN"
fi

git -C "$VENDOR" submodule update --init --recursive

ACTUAL="$(git -C "$VENDOR" rev-parse HEAD)"
[ "$ACTUAL" = "$PIN" ] || { echo "FATAL: vendor HEAD $ACTUAL != pin $PIN" >&2; exit 1; }
echo "OK: vendor/Ghostship @ $PIN, submodules:"
git -C "$VENDOR" submodule status --recursive

if compgen -G "$REPO_ROOT/overlay/patches/*.patch" >/dev/null; then
    "$REPO_ROOT/scripts/apply-overlay.sh"
fi
