#!/bin/bash
# Build the macOS app bundle and disk image, on a Mac. Needs Xcode (or the
# command line tools) and Homebrew. Homebrew no longer has SDL_image 1.2,
# so it is built from source into $KOBO_DEPS (default ~/devel/kobo-deps).
#
# Usage: packaging/build-macos.sh [version-suffix]   (e.g. -rc1)
# Output: build-macos/KoboDeluxe-<version>-macos-<arch>.dmg
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SRC/build-macos"
DEPS="${KOBO_DEPS:-$HOME/devel/kobo-deps}"
IMG=SDL_image-1.2.12

eval "$(/opt/homebrew/bin/brew shellenv)"
brew install cmake pkgconf sdl12-compat

if [ ! -e "$DEPS/lib/libSDL_image.dylib" ]; then
	mkdir -p "$DEPS/src"
	cd "$DEPS/src"
	curl -sSfLO "https://www.libsdl.org/projects/SDL_image/release/$IMG.tar.gz"
	tar xzf "$IMG.tar.gz"
	cd "$IMG"
	./configure --prefix="$DEPS" --disable-static --enable-imageio \
		--disable-sdltest
	make -j"$(sysctl -n hw.ncpu)"
	make install
fi

cmake -S "$SRC" -B "$OUT" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_PREFIX_PATH="$DEPS;$(brew --prefix)" \
	-DKOBO_VERSION_SUFFIX="${1:-}"
cmake --build "$OUT" -j"$(sysctl -n hw.ncpu)"
(cd "$OUT" && cpack -G DragNDrop)
