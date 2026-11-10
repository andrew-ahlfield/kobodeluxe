#!/usr/bin/env python3
"""Download and unpack the MSYS2 mingw64 packages needed to cross-compile
Kobo Deluxe for Windows, with all of their dependencies.

Usage: fetch-msys2-deps.py <workdir>

Leaves the unpacked tree in <workdir>/root/mingw64, which is what
KOBO_MINGW_ROOT should point at (see cmake/mingw-w64-x86_64.cmake).
"""

import os
import re
import subprocess
import sys
import tarfile

REPO = "https://repo.msys2.org/mingw/mingw64/"
ROOTS = [
    "mingw-w64-x86_64-sdl12-compat",
    "mingw-w64-x86_64-sdl-image",
    # sdl12-compat loads SDL2.dll at runtime; use real SDL2, not
    # sdl2-compat (which would pull in SDL3 as a third layer)
    "mingw-w64-x86_64-SDL2",
]
# Never needed at runtime here, or replaced by the real SDL2 above
SKIP = {
    "mingw-w64-x86_64-sdl2-compat",
    "mingw-w64-x86_64-sdl3",
    "mingw-w64-x86_64-vulkan",
    "mingw-w64-x86_64-vulkan-loader",
    "mingw-w64-x86_64-tzdata",
}
# Names that several packages provide, resolved to the one we want
PREFER = {"mingw-w64-x86_64-sdl2": "mingw-w64-x86_64-SDL2"}


def fetch(url, dest):
    if not os.path.exists(dest):
        subprocess.check_call(["curl", "-sSfL", "-o", dest, url])


def main():
    work = os.path.abspath(sys.argv[1])
    dl = os.path.join(work, "downloads")
    dbdir = os.path.join(work, "db")
    root = os.path.join(work, "root")
    os.makedirs(dl, exist_ok=True)
    os.makedirs(dbdir, exist_ok=True)

    db = os.path.join(dl, "mingw64.db")
    fetch(REPO + "mingw64.db", db)
    subprocess.check_call(["tar", "-xf", db, "-C", dbdir])

    pkgs, provides = {}, {}
    for d in os.listdir(dbdir):
        with open(os.path.join(dbdir, d, "desc")) as f:
            text = f.read()
        fields = {m.group(1): m.group(2).split("\n") for m in
                  re.finditer(r"%(\w+)%\n(.*?)(?:\n\n|\Z)", text, re.S)}
        name = fields["NAME"][0]
        pkgs[name] = fields
        for p in fields.get("PROVIDES", []):
            provides.setdefault(re.split("[=<>]", p)[0], name)

    def resolve(dep):
        dep = re.split("[=<>]", dep)[0]
        dep = PREFER.get(dep, dep)
        return dep if dep in pkgs else provides.get(dep)

    seen, stack = set(), list(ROOTS)
    while stack:
        name = resolve(stack.pop())
        if not name or name in seen or name in SKIP:
            continue
        seen.add(name)
        stack += pkgs[name].get("DEPENDS", [])

    os.makedirs(root, exist_ok=True)
    for name in sorted(seen):
        fn = pkgs[name]["FILENAME"][0]
        path = os.path.join(dl, fn)
        fetch(REPO + fn, path)
        subprocess.check_call(["tar", "--zstd", "-xf", path, "-C", root])
        print(fn)


if __name__ == "__main__":
    main()
