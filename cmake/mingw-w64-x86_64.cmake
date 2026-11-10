# Toolchain file for cross-compiling a 64-bit Windows build on Linux with
# mingw-w64. Set KOBO_MINGW_ROOT to a directory holding the Windows builds
# of the dependencies (bin/, include/, lib/), for example an unpacked set of
# MSYS2 mingw64 packages. See README.md.

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)

if(NOT KOBO_MINGW_ROOT)
	set(KOBO_MINGW_ROOT "$ENV{KOBO_MINGW_ROOT}")
endif()
set(CMAKE_FIND_ROOT_PATH "${KOBO_MINGW_ROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
