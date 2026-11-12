# Kobo Deluxe

Fork of David Olofson's Kobo Deluxe (`upstream` remote), an SDL 1.2 game
in C/C++ built with CMake. README.md has the full build instructions for
every platform; this file is the short version for building and
publishing releases.

## GitHub account

This repo belongs to **andrew-ahlfield**. Before pushing, tagging or
touching releases, check that `gh api user --jq .login` prints
`andrew-ahlfield`, and stop if it doesn't. In this repo `gh` would
otherwise pick the `upstream` remote (Olofson's repo) as its default, so
run `gh repo set-default andrew-ahlfield/kobodeluxe` once per clone, or
pass `-R andrew-ahlfield/kobodeluxe`.

## Releases

Tags are `vX.Y.Z` (release candidates `vX.Y.Z-rcN`). A release carries
four files:

| File | Built on | By |
|---|---|---|
| `KoboDeluxe-<version>-macos-universal.dmg` | a Mac | `packaging/build-macos.sh` |
| `KoboDeluxe-<version>-windows-x64.exe` | Linux | `packaging/build-windows.sh` |
| `KoboDeluxe-<version>-linux-amd64.deb` | Linux | `packaging/build-linux.sh`, then renamed (it writes `kobodeluxe_<version>_amd64.deb`) |
| `SHA256SUMS.txt` | anywhere | `sha256sum` of the other three, made last |

The Mac side tags the release, builds the disk image and creates the
GitHub release as a **draft** with the notes and the disk image. The
Linux build box then adds the rest:

```bash
git fetch --tags && git checkout vX.Y.Z      # the release's tag, exactly
packaging/build-linux.sh                      # add the suffix, e.g. -rc3, for a release candidate
cp build-linux/kobodeluxe_X.Y.Z_amd64.deb KoboDeluxe-X.Y.Z-linux-amd64.deb
packaging/build-windows.sh
gh release upload vX.Y.Z -R andrew-ahlfield/kobodeluxe \
	KoboDeluxe-X.Y.Z-linux-amd64.deb build-windows/KoboDeluxe-X.Y.Z-windows-x64.exe
gh release download vX.Y.Z -R andrew-ahlfield/kobodeluxe -p '*.dmg'
sha256sum KoboDeluxe-X.Y.Z-* > SHA256SUMS.txt   # all three, nothing else
gh release upload vX.Y.Z -R andrew-ahlfield/kobodeluxe SHA256SUMS.txt
```

Then check the draft lists all four files, and stop: **don't publish
it**. The Mac side publishes once the files are checked. A final release
is published with `--latest` and not as a pre-release, which is what
puts it in the repo page's sidebar as **Latest**. Release candidates are
pre-releases and never show there.

Release titles follow the owner's other repos: `vX.Y.Z: <what's new, in
a few words>`.

## Building the macOS release

```bash
packaging/build-macos.sh            # or e.g. packaging/build-macos.sh -rc3
```

Output: `build-macos/KoboDeluxe-<version>-macos-universal.dmg`, an ad hoc
signed universal (arm64 + x86_64) app for macOS 11 and later. Needs Xcode
or its command line tools, Homebrew, and dmgbuild (`brew install pipx &&
pipx install dmgbuild`). The first run builds the SDL stack from source
into `~/devel/kobo-deps/universal` and takes a few minutes; later runs skip
that. Run it in the background and wait for it to finish.

The script fails, rather than producing a broken disk image, if any binary
in the bundle isn't universal, links to a library outside the bundle, or
has a bad signature. If it fails, fix the cause; don't loosen the checks.

Rules:

- **Don't link Homebrew's libraries into the app.** They only cover the
  build machine's architecture. Homebrew provides cmake and pkgconf, and
  nothing else.
- **Dependency versions are pinned with SHA-256 checksums** in
  `packaging/build-macos.sh`. To bump one, change its URL, checksum and the
  version in its `built`/`mark` name together, then rebuild.
- **The app can't be notarized** (no paid Apple developer account). The ad
  hoc signature is done in the `install(CODE ...)` block in CMakeLists.txt,
  after `fixup_bundle`. Anything that changes files in the bundle after
  that breaks the signature.
- **Don't leave extra copies of `KoboDeluxe.app` on disk.** Launchpad lists
  every one Spotlight finds. The script deletes its staging copies; do the
  same for any you make.

Before committing C/C++ changes, check they build warning-free:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Maintainer && cmake --build build
```

## Getting the build to another Mac

- **`scp`, `rsync`, a USB drive or a network share** keep the app usable
  as is.
- **AirDrop, a browser download, Messages or email** add the quarantine
  flag. Gatekeeper then says it "could not verify" the app. After dragging
  it to Applications, clear the flag on the Mac that will run it:

  ```bash
  xattr -dr com.apple.quarantine /Applications/KoboDeluxe.app
  ```

  Or open it once from System Settings > Privacy & Security > Open Anyway.
- **To send the bare app instead of the disk image**, archive it with
  `ditto -c -k --keepParent KoboDeluxe.app KoboDeluxe.zip`. A plain
  `zip -r` breaks the symlinks in `Contents/Frameworks` and with them the
  signature.
- Don't re-sign the app on the other Mac; it's already signed.

## macOS specifics in the code

- `src/macos_hotkeys.c` turns the system keyboard shortcuts (Mission
  Control, Spaces, Cmd+Tab) off while a game is being played, because the
  fire button (Ctrl) plus the arrow keys would otherwise switch desktops. It
  uses a private window server call; there is no public API for this. The
  game states it applies in are listed in `kobo_gfxengine_t::frame()` in
  `src/kobo.cpp`.
- SDL_image is built without its ImageIO backend, which loads the game's
  PNGs wrong (sprites and fonts come out invisible).
