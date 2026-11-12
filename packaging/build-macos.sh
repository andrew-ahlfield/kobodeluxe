#!/bin/bash
# Build the macOS app bundle and disk image, on a Mac. Needs Xcode (or the
# command line tools), Homebrew, and dmgbuild (brew install pipx, then
# pipx install dmgbuild). Homebrew no longer has SDL_image 1.2, so it is
# built from source into $KOBO_DEPS (default ~/devel/kobo-deps).
#
# Usage: packaging/build-macos.sh [version-suffix]   (e.g. -rc1)
# Output: build-macos/KoboDeluxe-<version>-macos-<arch>.dmg
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SRC/build-macos"
STAGE="$OUT/stage"
DEPS="${KOBO_DEPS:-$HOME/devel/kobo-deps}"
IMG=SDL_image-1.2.12
DMGBUILD="${DMGBUILD:-$(command -v dmgbuild || echo "$HOME/.local/bin/dmgbuild")}"

eval "$(/opt/homebrew/bin/brew shellenv)"
brew install cmake pkgconf sdl12-compat libpng

# SDL_image with libpng. Its ImageIO backend loads the game's PNGs wrong
# on current macOS (every sprite and font comes out invisible).
if ! otool -L "$DEPS/lib/libSDL_image.dylib" 2>/dev/null | grep -q libpng
then
	mkdir -p "$DEPS/src"
	cd "$DEPS/src"
	[ -d "$IMG" ] || {
		curl -sSfLO "https://www.libsdl.org/projects/SDL_image/release/$IMG.tar.gz"
		tar xzf "$IMG.tar.gz"
	}
	cd "$IMG"
	make distclean > /dev/null 2>&1 || true
	# 1.2.12 predates libpng 1.6's const qualified prototypes; the
	# mismatch is harmless but current clang makes it an error
	./configure --prefix="$DEPS" --disable-static --disable-sdltest \
		--disable-imageio --enable-png --disable-png-shared \
		--disable-jpg --disable-tif --disable-webp \
		CPPFLAGS="-I$(brew --prefix)/include" \
		LDFLAGS="-L$(brew --prefix)/lib" \
		CFLAGS="-O2 -Wno-incompatible-function-pointer-types"
	make -j"$(sysctl -n hw.ncpu)"
	make install
fi

cmake -S "$SRC" -B "$OUT" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_PREFIX_PATH="$DEPS;$(brew --prefix)" \
	-DKOBO_VERSION_SUFFIX="${1:-}"
cmake --build "$OUT" -j"$(sysctl -n hw.ncpu)"

rm -rf "$STAGE"
cmake --install "$OUT" --prefix "$STAGE" --strip
APP="$STAGE/KoboDeluxe.app"

NAME="$(sed -n 's/^set(CPACK_PACKAGE_FILE_NAME "\(.*\)")$/\1/p' \
	"$OUT/CPackConfig.cmake")"
VOLUME="$(sed -n 's/^set(CPACK_DMG_VOLUME_NAME "\(.*\)")$/\1/p' \
	"$OUT/CPackConfig.cmake")"
rm -f "$OUT/$NAME.dmg"
"$DMGBUILD" -s "$SRC/packaging/dmg-settings.py" \
	-D app="$APP" \
	-D background="$SRC/packaging/dmg/background.png" \
	-D icon="$APP/Contents/Resources/kobodl.icns" \
	"$VOLUME" "$OUT/$NAME.dmg"

# Leave no other copy of the app on disk: Launchpad lists every .app that
# Spotlight finds, so build tree copies show up as extra, broken Kobos.
rm -rf "$STAGE" "$OUT/src/KoboDeluxe.app" "$OUT/_CPack_Packages"
echo "$OUT/$NAME.dmg"
