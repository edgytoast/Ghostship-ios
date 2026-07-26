#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/spikes/gs-sim-build/Release-iphonesimulator/Ghostship.app"
BUNDLE_ID="com.harbourmasters.ghostship"
SM64="$ROOT/oracle/shiphome/sm64.o2r"
UDID="63EA2491-3304-467E-B945-E279BE6FC3BD"   # Ghostship-Air (ours alone)

SHOT="sim-boot"; FRESH=0; SEED=1; ENVS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fresh) FRESH=1 ;;
        --no-seed) SEED=0 ;;
        --env) shift; ENVS+=("$1") ;;
        *) SHOT="$1" ;;
    esac
    shift
done

[[ -d "$APP" ]] || { echo "FATAL: no sim app at $APP — run scripts/build-sim.sh" >&2; exit 1; }
[[ -f "$SM64" ]] || { echo "FATAL: no sm64.o2r — run scripts/extract-sm64-o2r.sh" >&2; exit 1; }

xcrun simctl bootstatus "$UDID" -b
if [[ $FRESH -eq 1 ]]; then
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
fi
xcrun simctl install "$UDID" "$APP"

CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)
mkdir -p "$CONTAINER/Documents"
if [[ $SEED -eq 1 ]]; then
    cp "$SM64" "$CONTAINER/Documents/sm64.o2r"
    echo "seeded sm64.o2r into $CONTAINER/Documents"
fi

for e in "${ENVS[@]:-}"; do
    [[ -n "$e" ]] && export "SIMCTL_CHILD_${e%%=*}=${e#*=}"
done
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID"
echo "launched $BUNDLE_ID (env: ${ENVS[*]:-none}); waiting for boot…"

for _ in $(seq 1 12); do
    ls "$CONTAINER/Documents/logs" >/dev/null 2>&1 && break
    sleep 5
done
sleep 20   # engine boot + first scene

mkdir -p "$ROOT/artifacts"
xcrun simctl io "$UDID" screenshot "$ROOT/artifacts/$SHOT.png"
echo "captured artifacts/$SHOT.png"
sips -g pixelWidth -g pixelHeight "$ROOT/artifacts/$SHOT.png" 2>/dev/null | tail -2 || true

LOGDIR="$CONTAINER/Documents/logs"
if [[ -d "$LOGDIR" ]]; then
    echo "--- GS_PERF (simulator, non-authoritative) ---"
    grep -h "GS_PERF" "$LOGDIR"/* 2>/dev/null | tail -3 || echo "(no perf lines yet)"
fi
echo "container: $CONTAINER"
