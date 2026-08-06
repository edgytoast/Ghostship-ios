#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build-visionos"
GS_O2R="$ROOT/oracle/build-cmake/ghostship.o2r"
TEAM="${GS_IOS_TEAM:?set your Apple Developer team id (see README)}"

if [[ -d "$BUILD/Ghostship.xcarchive" ]]; then
    echo "build dir carries an xcarchive (post-export poison) — wiping $BUILD"
    rm -rf "$BUILD"
fi

[[ -d "$ROOT/vendor/Ghostship/.git" ]] || "$ROOT/scripts/bootstrap.sh"
"$ROOT/scripts/apply-overlay.sh"
[[ -f "$GS_O2R" ]] || "$ROOT/scripts/build-oracle.sh"

cmake --no-warn-unused-cli -S "$ROOT/vendor/Ghostship" -B "$BUILD" -GXcode \
    -DCMAKE_SYSTEM_NAME=visionOS -DPLATFORM=VISIONOS \
    -DCMAKE_OSX_SYSROOT=xros \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=2.0 -DCMAKE_BUILD_TYPE:STRING=Release \
    "-DSOH_REMOTE_CONSOLE=${SOH_REMOTE_CONSOLE:-ON}" \
    -DGS_VISIONOS=1 \
    -DCMAKE_XCODE_ATTRIBUTE_XROS_DEPLOYMENT_TARGET=2.0 \
    -DCMAKE_XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY=7 \
    -DCMAKE_XCODE_ATTRIBUTE_STRIP_INSTALLED_PRODUCT=NO \
    -DSDL_OPENGLES=OFF -DSDL_OPENGL=OFF \
    -DIOS_SIGNING=OFF \
    "-DGS_O2R_PATH=$GS_O2R" \
    "-DGS_IOS_SHELL_DIR=$ROOT/app/ios" \
    -DGS_IOS_BUNDLE_IDENTIFIER=com.rebelancap.ghostship \
    "-DGS_IOS_DEVELOPMENT_TEAM=$TEAM"

cmake --build "$BUILD" --config Release --target Ghostship --parallel 6 -- -allowProvisioningUpdates

APP="$BUILD/Release-xros/Ghostship.app"
[[ -d "$APP" ]] || { echo "FATAL: expected app at $APP" >&2; exit 1; }
lipo -info "$APP/Ghostship"
[[ -f "$APP/ghostship.o2r" && -f "$APP/config.yml" && -d "$APP/assets" ]] || {
    echo "FATAL: bundle resources missing (o2r/config.yml/assets)" >&2; exit 1; }
plutil -extract UIApplicationSceneManifest.UIApplicationSupportsMultipleScenes raw \
    "$APP/Info.plist" | grep -qx "true" || {
    echo "FATAL: UIApplicationSupportsMultipleScenes missing from Info.plist" >&2; exit 1; }
codesign -dv "$APP" 2>&1 | sed -n '1,3p' || true
echo "built (visionOS device): $APP"
