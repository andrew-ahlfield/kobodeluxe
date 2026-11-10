#!/bin/bash
# Build the Debian/Ubuntu package. Needs the build dependencies listed in
# README.md plus dpkg-dev (for dpkg-shlibdeps).
#
# Usage: packaging/build-linux.sh [version-suffix]   (e.g. -rc1)
# Output: build-linux/kobodeluxe_<version>_<arch>.deb
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SRC/build-linux"

cmake -S "$SRC" -B "$OUT" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DKOBO_VERSION_SUFFIX="${1:-}"
cmake --build "$OUT" -j"$(nproc)"
(cd "$OUT" && cpack -G DEB)
