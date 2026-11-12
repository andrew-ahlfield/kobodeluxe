cmake_minimum_required(VERSION 3.16)

project(KOBODELUXE C CXX)

# Default to an optimized build when no build type is given
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
	set(CMAKE_BUILD_TYPE Release CACHE STRING
		"Build type (Release, Debug, Maintainer)" FORCE)
endif()

set(KOBO_ORGANIZATION "OlofsonArcade")

set(VERSION_MAJOR 0)
set(VERSION_MINOR 6)
set(VERSION_PATCH 0)
set(VERSION_BUILD 0)

option(WIN32_ZIP_BUILD "Package Windows builds as a ZIP instead of an installer." OFF)
set(WORKDIR "${KOBODELUXE_SOURCE_DIR}/build" CACHE PATH
	"Top level build/staging directory.")
set(KOBO_EXTRA_LIBRARIES "" CACHE STRING "Extra libraries to link with.")

message(".-----------------------------------------")
message("|      WIN32_ZIP_BUILD: ${WIN32_ZIP_BUILD}")
message("|              WORKDIR: ${WORKDIR}")
message("| KOBO_EXTRA_LIBRARIES: ${KOBO_EXTRA_LIBRARIES}")
message("'-----------------------------------------")

set(KOBO_APPLICATION "KoboDeluxe")
if(WIN32)
	set(KOBO_PACKAGE_NAME "KoboDeluxe")
else(WIN32)
	set(KOBO_PACKAGE_NAME "kobodeluxe")
endif(WIN32)

if(VERSION_BUILD)
	set(VERSION_STRING "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}.${VERSION_BUILD}")
else(VERSION_BUILD)
	set(VERSION_STRING "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
endif(VERSION_BUILD)
# Prerelease builds: e.g. -DKOBO_VERSION_SUFFIX=-rc1 gives "0.6.0-rc1"
set(KOBO_VERSION_SUFFIX "" CACHE STRING "Version suffix, such as -rc1.")
# (macOS wants a purely numeric CFBundleVersion)
set(KOBO_BASE_VERSION "${VERSION_STRING}")
set(VERSION_STRING "${VERSION_STRING}${KOBO_VERSION_SUFFIX}")
set(PACKAGE "${KOBO_PACKAGE_NAME}-${VERSION_STRING}")

# Release build: full optimization, no debug features, no debug info
set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG")

# Maintainer build: No optimizations, lots of warnings, fail on warnings
set(f "-O0 -g -Wall -Wwrite-strings -Wcast-align")
set(f "${f} -Wbad-function-cast -Waggregate-return")
set(f "${f} -Wstrict-prototypes -fno-builtin -Wshadow")
set(f "${f} -Wdeclaration-after-statement -Wmissing-prototypes")
set(f "${f} -Wmissing-declarations -Wdisabled-optimization")
set(CMAKE_C_FLAGS_MAINTAINER "${f} -Werror")

# Debug build: Maintainer + extra debug features, don't fail on warnings
set(f "${f} -DDEBUG")
set(CMAKE_C_FLAGS_DEBUG ${f})

if(WIN32)
	# Flat layout: the game looks for gfx/ and sfx/ next to kobodl.exe
	set(KOBO_BIN_DIR ".")
	set(KOBO_SHARE_DIR ".")
	set(KOBO_DOC_DIR "doc")
elseif(APPLE)
	# Self-contained KoboDeluxe.app: data and documents both go in
	# Contents/Resources, so the disk image holds nothing but the app
	set(KOBO_BUNDLE_NAME "KoboDeluxe")
	set(KOBO_BIN_DIR ".")
	set(KOBO_SHARE_DIR "${KOBO_BUNDLE_NAME}.app/Contents/Resources")
	set(KOBO_DOC_DIR "${KOBO_SHARE_DIR}/Documentation")
else()
	set(KOBO_BIN_DIR "bin")
	set(KOBO_SHARE_DIR "share/${KOBO_PACKAGE_NAME}")
	set(KOBO_DOC_DIR "share/doc/${KOBO_PACKAGE_NAME}")
endif()

add_subdirectory(src)

# Game data files
install(DIRECTORY data/gfx
	DESTINATION "${KOBO_SHARE_DIR}"
	FILES_MATCHING
	PATTERN "*.png"
	PATTERN "*.gpl"
	PATTERN "*.theme")
install(DIRECTORY data/sfx
	DESTINATION "${KOBO_SHARE_DIR}"
	FILES_MATCHING
	PATTERN "*.agw"
	PATTERN "*.mid"
	PATTERN "*.h")

# Documentation
file(GLOB doc_files
	"${KOBODELUXE_SOURCE_DIR}/*.md"
	"${KOBODELUXE_SOURCE_DIR}/COPYING*")
list(REMOVE_ITEM doc_files "${KOBODELUXE_SOURCE_DIR}/INSTALL.md")
install(FILES ${doc_files}
	DESTINATION "${KOBO_DOC_DIR}")

# Desktop entry
if(NOT WIN32 AND NOT APPLE)
	set(KOBO_DE_FILE "net.olofson.${KOBO_PACKAGE_NAME}.desktop")
	# Named to match Icon=kobodl in the desktop file
	install(FILES "${KOBODELUXE_SOURCE_DIR}/icons/kobodl.png"
		DESTINATION "share/pixmaps")
	install(FILES "${KOBODELUXE_SOURCE_DIR}/icons/${KOBO_DE_FILE}"
		DESTINATION "share/applications")
endif()

# macOS: make the app bundle self-contained, after everything is in it.
# Copy the dylibs into the bundle, point the binary at them, and re-sign
# (ad hoc) since rewriting load paths invalidates the signatures.
if(APPLE)
	# sdl12-compat loads SDL2 at runtime, and if SDL2 is itself sdl2-compat
	# (as in current Homebrew), that loads SDL3. Both look next to
	# themselves first, so they go in Contents/Frameworks with libSDL.
	find_library(KOBO_SDL2_DYLIB NAMES SDL2-2.0.0 SDL2 REQUIRED)
	find_library(KOBO_SDL3_DYLIB NAMES SDL3)
	set(KOBO_RUNTIME_DYLIBS "${KOBO_SDL2_DYLIB}")
	if(KOBO_SDL3_DYLIB)
		list(APPEND KOBO_RUNTIME_DYLIBS "${KOBO_SDL3_DYLIB}")
	endif()
	# (KOBO_BIN_DIR is "." here; fixup_bundle compares paths as strings)
	set(KOBO_APP "\${CMAKE_INSTALL_PREFIX}/${KOBO_BUNDLE_NAME}.app")
	install(CODE "
		include(BundleUtilities)
		file(COPY ${KOBO_RUNTIME_DYLIBS}
			DESTINATION \"${KOBO_APP}/Contents/Frameworks\"
			FOLLOW_SYMLINK_CHAIN)
		fixup_bundle(\"${KOBO_APP}\" \"\" \"\")
		execute_process(COMMAND codesign --force --deep --sign -
			\"${KOBO_APP}\")
	")
endif()

# CPack general
if(WIN32)
	if(WIN32_ZIP_BUILD)
		set(CPACK_GENERATOR "ZIP")
	else()
		set(CPACK_GENERATOR "NSIS")
	endif()
elseif(APPLE)
	set(CPACK_GENERATOR "DragNDrop")
else()
	# Linux packages
	set(CPACK_GENERATOR "DEB" "RPM" "TBZ2")
	set(CPACK_SET_DESTDIR ON)
	set(CPACK_PACKAGE_RELOCATABLE false)
endif()
set(CPACK_STRIP_FILES true)
set(CPACK_PACKAGE_NAME "${KOBO_PACKAGE_NAME}")
set(CPACK_PACKAGE_VERSION "${VERSION_STRING}")
set(CPACK_PACKAGE_CONTACT "David Olofson <david@olofson.net>")
set(CPACK_RESOURCE_FILE_LICENSE "${KOBODELUXE_SOURCE_DIR}/COPYING")
set(CPACK_RESOURCE_FILE_README "${KOBODELUXE_SOURCE_DIR}/README.md")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Arcade style 2D shooter")
set(CPACK_PACKAGE_DESCRIPTION "Frantic 80's style 2D shooter, inspired by the look and feel of 90's arcades.")

# Package file names: KoboDeluxe-<version>-<platform>
if(WIN32)
	set(CPACK_PACKAGE_FILE_NAME "KoboDeluxe-${VERSION_STRING}-windows-x64")
elseif(APPLE)
	set(CPACK_PACKAGE_FILE_NAME
		"KoboDeluxe-${VERSION_STRING}-macos-${CMAKE_SYSTEM_PROCESSOR}")
endif()

# CPack DEB
# Debian sorts "~" before the release, so 0.6.0~rc1 < 0.6.0
string(REPLACE "-" "~" CPACK_DEBIAN_PACKAGE_VERSION "${VERSION_STRING}")
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_DEBIAN_PACKAGE_SECTION "games")
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_SUMMARY "${CPACK_PACKAGE_DESCRIPTION_SUMMARY}")
set(CPACK_DEBIAN_PACKAGE_DESCRIPTION
"Arcade style 2D shooter\n Kobo Deluxe is a frantic 80's style 2D shooter, inspired by the look and\n feel of 90's arcade cabinets. The game play is fast and unforgiving.\n A true challenge in the spirit of the arcade era!")

# CPack PRM
set(CPACK_RPM_PACKAGE_GROUP "Games")
set(CPACK_RPM_PACKAGE_DESCRIPTION "${CPACK_DEBIAN_PACKAGE_DESCRIPTION}")
set(CPACK_RPM_PACKAGE_LICENSE "GPLv2+")
set(CPACK_RPM_PACKAGE_URL "http://kobodeluxe.com")
set(CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION
	/usr/share/applications /usr/share/pixmaps)

# CPack NSIS (Windows installer)
set(CPACK_PACKAGE_VENDOR "${KOBO_ORGANIZATION}")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "${KOBO_APPLICATION}")
set(CPACK_PACKAGE_EXECUTABLES "kobodl" "Kobo Deluxe")
set(CPACK_NSIS_DISPLAY_NAME "Kobo Deluxe ${VERSION_STRING}")
set(CPACK_NSIS_PACKAGE_NAME "Kobo Deluxe")
set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES64")
set(CPACK_NSIS_MUI_ICON "${KOBODELUXE_SOURCE_DIR}/icons/windows/kobodl.ico")
set(CPACK_NSIS_MUI_UNIICON "${KOBODELUXE_SOURCE_DIR}/icons/windows/kobodl.ico")
set(CPACK_NSIS_INSTALLED_ICON_NAME "kobodl.exe")
set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
set(CPACK_NSIS_URL_INFO_ABOUT "https://github.com/andrew-ahlfield/kobodeluxe")
set(CPACK_NSIS_MUI_FINISHPAGE_RUN "kobodl.exe")
# SDLmain redirects console output to these files next to the .exe
set(CPACK_NSIS_EXTRA_UNINSTALL_COMMANDS
	"Delete '$INSTDIR\\\\stdout.txt'\nDelete '$INSTDIR\\\\stderr.txt'")

# CPack DragNDrop (plain macOS disk image). packaging/build-macos.sh
# builds the release image with dmgbuild instead, for the window layout.
set(CPACK_DMG_VOLUME_NAME "Kobo Deluxe ${VERSION_STRING}")
# No click-through licence when opening the disk image; COPYING is inside
set(CPACK_DMG_SLA_USE_RESOURCE_FILE_LICENSE OFF)

include(CPack)
