#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$REPO_ROOT/oracle/build-cmake"
ROM="$REPO_ROOT/work/gamedata/baserom.us.z64"
SHIPHOME="$REPO_ROOT/oracle/shiphome"
TORCH="$BUILD/TorchExternal/src/TorchExternal-build/torch"
EXPECTED_SHA1="9bef1128717f958171a4afac3ed78ee2bb4e86ce"  # SM64 (US), in-app allowlist
PORT_VERSION="2.1.0"  # must match gBuildVersionMajor.Minor (o2r portVersion gate)

[ -x "$TORCH" ] || { echo "FATAL: torch not built at $TORCH (run build-oracle.sh)" >&2; exit 1; }
[ -f "$ROM" ] || { echo "FATAL: ROM missing at $ROM" >&2; exit 1; }
[ -f "$BUILD/config.yml" ] || { echo "FATAL: config.yml not in build dir" >&2; exit 1; }
[ -d "$BUILD/assets" ] || { echo "FATAL: assets/ not in build dir" >&2; exit 1; }

ACTUAL_SHA1=$(shasum -a 1 "$ROM" | cut -d' ' -f1)
[ "$ACTUAL_SHA1" = "$EXPECTED_SHA1" ] || { echo "FATAL: ROM sha1 $ACTUAL_SHA1 != $EXPECTED_SHA1" >&2; exit 1; }

mkdir -p "$SHIPHOME"
"$TORCH" o2r "$ROM" -s "$BUILD" -d "$SHIPHOME" -u "$PORT_VERSION"

[ -s "$SHIPHOME/sm64.o2r" ] || { echo "FATAL: sm64.o2r not produced in $SHIPHOME" >&2; exit 1; }
echo "OK:"; ls -la "$SHIPHOME/sm64.o2r"
