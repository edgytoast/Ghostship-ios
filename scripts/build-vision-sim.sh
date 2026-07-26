#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/spikes/gs-vision-sim-build"
GS_O2R="$ROOT/oracle/build-cmake/ghostship.o2r"

[[ -d "$ROOT/vendor/Ghostship/.git" ]] || "$ROOT/scripts/bootstrap.sh"
"$ROOT/scripts/apply-overlay.sh"
[[ -f "$GS_O2R" ]] || "$ROOT/scripts/build-oracle.sh"

cmake --no-warn-unused-cli -S "$ROOT/vendor/Ghostship" -B "$BUILD" -GXcode \
    -DCMAKE_SYSTEM_NAME=visionOS -DPLATFORM=SIMULATOR_VISIONOS \
    -DCMAKE_OSX_SYSROOT=xrsimulator \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=2.0 -DCMAKE_BUILD_TYPE:STRING=Release \
    -DGS_VISIONOS=1 \
    -DCMAKE_XCODE_ATTRIBUTE_XROS_DEPLOYMENT_TARGET=2.0 \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="" \
    -DSDL_OPENGLES=OFF -DSDL_OPENGL=OFF \
    -DIOS_SIGNING=OFF \
    "-DGS_O2R_PATH=$GS_O2R" \
    "-DGS_IOS_SHELL_DIR=$ROOT/app/ios"

cmake --build "$BUILD" --config Release --target Ghostship --parallel 6

APP="$BUILD/Release-xrsimulator/Ghostship.app"
[[ -d "$APP" ]] || { echo "FATAL: expected app at $APP" >&2; exit 1; }
lipo -info "$APP/Ghostship"
[[ -f "$APP/ghostship.o2r" && -f "$APP/config.yml" && -d "$APP/assets" ]] || {
    echo "FATAL: bundle resources missing (o2r/config.yml/assets)" >&2; exit 1; }
plutil -extract UIApplicationSceneManifest.UIApplicationSupportsMultipleScenes raw \
    "$APP/Info.plist" | grep -qx "true" || {
    echo "FATAL: UIApplicationSupportsMultipleScenes missing from Info.plist" >&2; exit 1; }
echo "built (visionOS simulator): $APP"
