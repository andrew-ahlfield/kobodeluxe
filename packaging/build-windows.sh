#!/bin/bash
# Cross-compile Kobo Deluxe for 64-bit Windows on Linux and build the NSIS
# installer. Needs: mingw-w64, cmake, nsis, curl, zstd, python3.
#
# Usage: packaging/build-windows.sh [version-suffix]   (e.g. -rc1)
# Output: build-windows/KoboDeluxe-<version>-windows-x64.exe
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SRC/build-windows"
DEPS="$OUT/deps"

python3 -I "$SRC/packaging/fetch-msys2-deps.py" "$DEPS" > /dev/null

cmake -S "$SRC" -B "$OUT" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_TOOLCHAIN_FILE="$SRC/cmake/mingw-w64-x86_64.cmake" \
	-DKOBO_MINGW_ROOT="$DEPS/root/mingw64" \
	-DKOBO_VERSION_SUFFIX="${1:-}"
cmake --build "$OUT" -j"$(nproc)"
(cd "$OUT" && cpack -G NSIS)
