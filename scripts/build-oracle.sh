#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$REPO_ROOT/vendor/Ghostship"
BUILD="$REPO_ROOT/oracle/build-cmake"
M3=/opt/homebrew/opt/mbedtls@3

[ -d "$VENDOR/.git" ] || "$REPO_ROOT/scripts/bootstrap.sh"
"$REPO_ROOT/scripts/apply-overlay.sh"

cmake --no-warn-unused-cli -S "$VENDOR" -B "$BUILD" -GNinja \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DPython3_EXECUTABLE="$(which python3)" \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=TRUE \
    -DMBEDTLS_INCLUDE_DIRS="$M3/include" \
    -DMBEDTLS_LIBRARY="$M3/lib/libmbedtls.dylib" \
    -DMBEDX509_LIBRARY="$M3/lib/libmbedx509.dylib" \
    -DMBEDCRYPTO_LIBRARY="$M3/lib/libmbedcrypto.dylib" \
    -DMBEDTLS_VERSION_GREATER_THAN_3="$M3/include"

cmake --build "$BUILD" --parallel 6

cmake --build "$BUILD" --parallel 6 --target GeneratePortO2R

git -C "$VENDOR/libultraship" checkout -- src/generate_keys_header
ALLOWED=$(grep -h '^+++ b/' "$REPO_ROOT"/overlay/patches/*.patch | sed 's|^+++ b/||' | sort -u)
DIRTY=$( (git -C "$VENDOR" diff --name-only | grep -vx "libultraship"; git -C "$VENDOR/libultraship" diff --name-only | sed 's|^|libultraship/|') | sort -u)
BAD=$(comm -23 <(echo "$DIRTY") <(echo "$ALLOWED"))
if [ -n "$BAD" ]; then
    echo "FATAL: vendor tree modified beyond the overlay series:" >&2
    echo "$BAD" >&2
    exit 1
fi

echo "OK: oracle built:"
ls -la "$BUILD/Ghostship" "$BUILD/ghostship.o2r"
