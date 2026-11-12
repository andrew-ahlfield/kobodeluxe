#!/bin/bash
# Build the macOS app bundle and disk image, on a Mac. Needs Xcode (or the
# command line tools), Homebrew (for cmake and pkgconf only), and dmgbuild
# (brew install pipx, then pipx install dmgbuild).
#
# The app is universal (Apple Silicon + Intel) and runs on macOS 11 and
# later. Homebrew's libraries are built for the build machine only, so the
# SDL stack and libpng are built from pinned source releases instead, into
# $KOBO_DEPS/universal (default ~/devel/kobo-deps). That takes a few minutes
# the first time and is skipped after that.
#
# The app is ad hoc signed, not notarized (that needs a paid Apple
# developer account), so a copy that arrives by AirDrop, browser download
# or Messages gets quarantined. See "Installing on another Mac" in
# CLAUDE.md.
#
# Usage: packaging/build-macos.sh [version-suffix]   (e.g. -rc1)
# Output: build-macos/KoboDeluxe-<version>-macos-universal.dmg
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SRC/build-macos"
STAGE="$OUT/stage"
DEPS_ROOT="${KOBO_DEPS:-$HOME/devel/kobo-deps}"
DEPS="$DEPS_ROOT/universal"
DL="$DEPS_ROOT/src"
DMGBUILD="${DMGBUILD:-$(command -v dmgbuild || echo "$HOME/.local/bin/dmgbuild")}"
NCPU="$(sysctl -n hw.ncpu)"

export MACOSX_DEPLOYMENT_TARGET=11.0
ARCHS="arm64;x86_64"

eval "$(/opt/homebrew/bin/brew shellenv)"
brew install cmake pkgconf

mkdir -p "$DEPS" "$DL"
# Keep pkg-config from offering Homebrew's single-architecture libraries
export PKG_CONFIG_LIBDIR="$DEPS/lib/pkgconfig"

# fetch <url> <sha256>: download into $DL once, verify, unpack to a fresh
# build directory and cd into it
fetch()
{
	local file="$DL/$(basename "$1")"
	[ -f "$file" ] || curl -sSfL -o "$file" "$1"
	echo "$2  $file" | shasum -a 256 -c - > /dev/null || {
		echo "Checksum mismatch: $file" >&2
		exit 1
	}
	local dir="$DL/build/$(basename "$file" | sed 's/\.tar\..*$//')"
	rm -rf "$dir"
	mkdir -p "$dir"
	tar xf "$file" -C "$dir" --strip-components 1
	cd "$dir"
}

# built <name>: true if <name> is already in $DEPS
built() { [ -f "$DEPS/.built-$1" ]; }
mark() { touch "$DEPS/.built-$1"; }

cmake_dep()
{
	cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX="$DEPS" \
		-DCMAKE_PREFIX_PATH="$DEPS" \
		-DCMAKE_OSX_ARCHITECTURES="$ARCHS" \
		-DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET" \
		"$@" > /dev/null
	cmake --build build -j"$NCPU" > /dev/null
	cmake --install build > /dev/null
}

# libpng, static, linked into SDL_image. (No SIMD: libpng picks it from the
# build machine's CPU, which is wrong for the other half of the binary.)
if ! built libpng-1.6.59; then
	echo "Building libpng..."
	fetch https://download.sourceforge.net/libpng/libpng-1.6.59.tar.xz \
		d80dd2a38a37f803cb9b6ac7b14bd6e74ddc3b654780a8380bdf93523fdb4389
	cmake_dep -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF \
		-DPNG_TOOLS=OFF -DPNG_FRAMEWORK=OFF \
		-DPNG_HARDWARE_OPTIMIZATIONS=OFF
	mark libpng-1.6.59
fi

# SDL3, which sdl2-compat runs on
if ! built SDL3-3.4.20; then
	echo "Building SDL3..."
	fetch https://github.com/libsdl-org/SDL/releases/download/release-3.4.20/SDL3-3.4.20.tar.gz \
		f3bb06f55bed9557227a700af2ea62e49497ebdf58037732a731a5fb3ef8581f
	cmake_dep -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TESTS=OFF \
		-DSDL_EXAMPLES=OFF
	mark SDL3-3.4.20
fi

# SDL2 (sdl2-compat), which sdl12-compat runs on
if ! built sdl2-compat-2.32.74; then
	echo "Building sdl2-compat..."
	fetch https://github.com/libsdl-org/sdl2-compat/releases/download/release-2.32.74/sdl2-compat-2.32.74.tar.gz \
		ec68abde77e2e459c8abc4f9587b8976b5d2a657b2bfda2fb3a079b0f8924588
	cmake_dep -DSDL2COMPAT_TESTS=OFF -DSDL2COMPAT_STATIC=OFF
	mark sdl2-compat-2.32.74
fi

# SDL 1.2 (sdl12-compat), which the game is written against
if ! built sdl12-compat-1.2.78; then
	echo "Building sdl12-compat..."
	fetch https://github.com/libsdl-org/sdl12-compat/releases/download/release-1.2.78/sdl12-compat-1.2.78.tar.gz \
		bdc5277cf3a8ae18c7493a7d4d0867c53439a9e5a661133dcf1f2eb0b9ddca4d
	cmake_dep -DSDL12TESTS=OFF -DSDL12DEVEL=ON \
		-DSDL2_INCLUDE_DIR="$DEPS/include/SDL2"
	mark sdl12-compat-1.2.78
fi

# SDL_image 1.2 with libpng. Its ImageIO backend loads the game's PNGs
# wrong on current macOS (every sprite and font comes out invisible).
if ! built SDL_image-1.2.12; then
	echo "Building SDL_image..."
	fetch https://www.libsdl.org/projects/SDL_image/release/SDL_image-1.2.12.tar.gz \
		0b90722984561004de84847744d566809dbb9daf732a9e503b91a1b5a84e5699
	# 1.2.12 predates libpng 1.6's const qualified prototypes; the
	# mismatch is harmless but current clang makes it an error
	PATH="$DEPS/bin:$PATH" ./configure --prefix="$DEPS" \
		--disable-static --disable-sdltest --disable-dependency-tracking \
		--disable-imageio --enable-png --disable-png-shared \
		--disable-jpg --disable-tif --disable-webp \
		CPPFLAGS="-I$DEPS/include" \
		LDFLAGS="-L$DEPS/lib" \
		CFLAGS="-O2 -arch arm64 -arch x86_64 -Wno-incompatible-function-pointer-types" \
		> /dev/null
	make -j"$NCPU" > /dev/null
	make install > /dev/null
	mark SDL_image-1.2.12
fi
cd "$SRC"

# Fresh configure (a cache from an older build may point at Homebrew), and
# only $DEPS on the search path, so nothing single-architecture can sneak
# into the app
rm -rf "$OUT"
cmake -S "$SRC" -B "$OUT" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_PREFIX_PATH="$DEPS" \
	-DCMAKE_IGNORE_PREFIX_PATH="$(brew --prefix);/usr/local" \
	-DCMAKE_OSX_ARCHITECTURES="$ARCHS" \
	-DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET" \
	-DKOBO_VERSION_SUFFIX="${1:-}"
cmake --build "$OUT" -j"$NCPU"

rm -rf "$STAGE"
cmake --install "$OUT" --prefix "$STAGE" --strip
APP="$STAGE/KoboDeluxe.app"

# Check the bundle before packaging it: every binary universal, nothing
# linked from outside the bundle or the system, signature intact
for f in "$APP/Contents/MacOS/"* "$APP/Contents/Frameworks/"*; do
	[ -L "$f" ] && continue
	archs="$(lipo -archs "$f")"
	case "$archs" in
	  *arm64*x86_64*|*x86_64*arm64*) ;;
	  *) echo "Not universal ($archs): $f" >&2; exit 1 ;;
	esac
	# (dependency lines are the indented ones; the others name the file
	# and, for universal files, each architecture)
	if otool -L "$f" | grep $'^\t' | grep -v -e '@executable_path' \
			-e '@loader_path' -e '@rpath' -e '/usr/lib/' \
			-e '/System/Library/'; then
		echo "Links outside the bundle: $f" >&2
		exit 1
	fi
done
codesign --verify --deep --strict "$APP"

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

# Check the app as users will get it, from the disk image (dmgbuild can add
# Finder metadata that breaks the signature)
MNT="$(mktemp -d)"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MNT" "$OUT/$NAME.dmg"
if ! codesign --verify --deep --strict "$MNT/KoboDeluxe.app"; then
	hdiutil detach -quiet "$MNT"
	echo "The app in the disk image fails signature verification" >&2
	exit 1
fi
hdiutil detach -quiet "$MNT"
rmdir "$MNT"

# Leave no other copy of the app on disk: Launchpad lists every .app that
# Spotlight finds, so build tree copies show up as extra, broken Kobos.
rm -rf "$STAGE" "$OUT/src/KoboDeluxe.app" "$OUT/_CPack_Packages"
echo "$OUT/$NAME.dmg"
