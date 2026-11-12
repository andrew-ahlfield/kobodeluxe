*(From the original README)*

# Kobo Deluxe
#### An enhanced port of the scrolling video game XKobo

### DESCRIPTION
       Kobo  Deluxe  is  a  3'rd person scrolling 2D shooter with a simple and
       responsive control system - which you'll need to  tackle  the  tons  of
       enemy  ships  that shoot at you, chase you, circle around you shooting,
       or even launch other ships at you, while you're trying to  destroy  the
       labyrinth shaped bases. There are 50 action packed levels with smoothly
       increasing difficulty,  and  different  combinations  of  enemies  that
       require different tactics to be dealt with successfully.

       Kobo Deluxe has an improved graphics engine that delivers smoother ani-
       mation, while keeping the game logic totally accurate  and  predictable
       regardless  of  frame  rate.  It also adds sound effects, new graphics,
       fullscreen mode, four extra skill levels  with  smoother  gameplay  and
       various  other  features expected from a modern game. (There is still a
       "Clasic" mode that plays exactly like the original XKobo.)

       Kobo Deluxe uses SDL for sound, graphics and input, and builds and runs
       on all major operating systems, as well as some more unusual platforms.
       It can also use OpenGL for accelerated rendering, through glSDL.

       In short, Kobo Deluxe is loads of classical arcade style fun  for  just
       about any machine with graphics and sound!

## Building on Linux

Kobo Deluxe is written against SDL 1.2. Current distributions ship SDL 1.2 as
sdl12-compat, which runs SDL 1.2 programs on top of SDL2, so the stock
packages are all that is needed. On Debian or Ubuntu:

```bash
sudo apt install build-essential cmake libsdl1.2-dev libsdl-image1.2-dev
```

(On Ubuntu 24.04 and later, `libsdl1.2-dev` is provided by sdl12-compat.)

Then, from the top of the source tree:

```bash
cmake -B build
cmake --build build -j
```

The build type defaults to `Release`. Pass `-DCMAKE_BUILD_TYPE=Debug` for a
debug build.

### Running

The game runs straight from the build tree and finds its data in `data/`:

```bash
./build/src/kobodl
```

Player profiles, scores and the config file go in `~/.kobodeluxe`, which is
created on first run. Run `./build/src/kobodl -help` for the command line
options.

### Installing

```bash
sudo cmake --install build
```

This installs to `/usr/local` by default; pass `-DCMAKE_INSTALL_PREFIX=...`
when configuring to change that. The `configure`, `make-all` and
`build-packages` scripts are the original packaging helpers and are not
needed for a normal build.

## Installers

Each script below builds one platform's installer from a clean tree. An
optional argument adds a version suffix, e.g. `-rc1` for a release
candidate.

| Platform | Script | Runs on | Output |
|---|---|---|---|
| Debian, Ubuntu | `packaging/build-linux.sh` | Linux | `build-linux/kobodeluxe_<version>_amd64.deb` |
| Windows 10/11 (x64) | `packaging/build-windows.sh` | Linux | `build-windows/KoboDeluxe-<version>-windows-x64.exe` |
| macOS (Apple silicon) | `packaging/build-macos.sh` | macOS | `build-macos/KoboDeluxe-<version>-macos-arm64.dmg` |

The application icons in `icons/` are drawn from the game's own sprites by
`icons/make-icons.py`, and the disk image background by
`packaging/make-dmg-background.py`. Both need Pillow; rerun them after
changing either.

### Windows

The Windows build is cross-compiled on Linux with mingw-w64, using the
SDL 1.2 (sdl12-compat), SDL2 and SDL_image 1.2 DLLs from MSYS2, which the
script downloads. The installer is made with NSIS:

```bash
sudo apt install mingw-w64 nsis zstd
packaging/build-windows.sh
```

The installer puts the game in Program Files with a Start menu entry and an
uninstaller. Player profiles, scores and settings go in
`%APPDATA%\KoboDeluxe`.

### macOS

Build on the Mac itself, with Xcode or its command line tools and Homebrew
installed. The script installs cmake, libpng and sdl12-compat with Homebrew,
and builds SDL_image 1.2 (with libpng) from source into `~/devel/kobo-deps`,
since Homebrew no longer has it. The disk image is laid out by dmgbuild:

```bash
brew install pipx && pipx install dmgbuild
packaging/build-macos.sh
```

The disk image holds `KoboDeluxe.app`, with its libraries and documents
inside it, and a shortcut to drag it onto Applications. The script deletes
every other copy of the app it made, so Launchpad only ever lists the
installed one. The app is signed ad hoc, not with an Apple
Developer ID, so the first time it is opened macOS will refuse; open it once
from System Settings > Privacy & Security > Open Anyway. Player data goes in
`~/.kobodeluxe`.
