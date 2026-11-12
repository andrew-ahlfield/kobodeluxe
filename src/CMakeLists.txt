set(sources
	gamestate.cpp
	map.cpp
	radar.cpp
	cfgform.cpp
	dashboard.cpp
	enemy.cpp
	game.cpp
	logger.c
	pfile.cpp
	score.cpp
	sound.cpp
	filemap.cpp
	myship.cpp
	random.cpp
	cfgparse.cpp
	gamectl.cpp
	kobo.cpp
	manage.cpp
	prefs.cpp
	screen.cpp
	states.cpp
	enemies.cpp
	form.cpp
	options.cpp
	scenes.cpp
	eel/e_builtin.c
	eel/e_getargs.c
	eel/e_lexer.c
	eel/e_path.c
	eel/e_register.c
	eel/e_script.c
	eel/e_symtab.c
	eel/e_util.c
	eel/eel.c
	graphics/cs.c
	graphics/display.cpp
	graphics/filters.c
	graphics/gfxengine.cpp
	graphics/glSDL.c
	graphics/region.c
	graphics/sofont.cpp
	graphics/sprite.c
	graphics/toolkit.cpp
	graphics/vidmodes.c
	graphics/window.cpp
	sound/a_agw.c
	sound/a_bus.c
	sound/a_channel.c
	sound/a_commands.c
	sound/a_control.c
	sound/a_delay.c
	sound/a_events.c
	sound/a_filters.c
	sound/a_globals.c
	sound/a_limiter.c
	sound/a_midi.c
	sound/a_midicon.c
	sound/a_midifile.c
	sound/a_midisock.c
	sound/a_patch.c
	sound/a_pitch.c
	sound/a_plugin.c
	sound/a_sequencer.c
	sound/a_struct.c
	sound/a_voice.c
	sound/a_wave.c
	sound/a_wca.c
	sound/audio.c
	sound/audiodev.c
	sound/sfifo.c
)

include(FindPkgConfig)
include(CheckIncludeFiles)
include(CheckFunctionExists)
include(CheckCSourceCompiles)

include_directories(${KOBODELUXE_SOURCE_DIR})
include_directories(${KOBODELUXE_SOURCE_DIR}/src)
include_directories(${KOBODELUXE_SOURCE_DIR}/src/graphics)
include_directories(${KOBODELUXE_SOURCE_DIR}/src/eel)
include_directories(${KOBODELUXE_SOURCE_DIR}/src/sound)
include_directories(${KOBODELUXE_SOURCE_DIR}/data/sfx)
include_directories(${CMAKE_BINARY_DIR}/include)

set(KOBO_EXE_SUFFIX "")

find_package(SDL REQUIRED)
include_directories(${SDL_INCLUDE_DIR})

find_package(SDL_image REQUIRED)
include_directories(${SDLIMAGE_INCLUDE_DIR})

#pkg_search_module(SDL2 REQUIRED sdl2)
#include_directories(${SDL2_INCLUDE_DIRS})
#link_directories(${SDL2_LIBDIR})

#pkg_search_module(SDL2IMAGE REQUIRED SDL2_image>=2.0.0)
#include_directories(${SDL2IMAGE_INCLUDE_DIRS})

#find_package(PNG REQUIRED)
#include_directories(${PNG_INCLUDE_DIR})

#find_package(AUDIALITY2 REQUIRED)
#include_directories(${AUDIALITY2_INCLUDE_DIR})
#pkg_search_module(AUDIALITY2 REQUIRED audiality2)
#include_directories(${AUDIALITY2_INCLUDE_DIRS})

set(RES_FILES "")
if(MINGW)
	set(RES_FILES "${KOBODELUXE_SOURCE_DIR}/icons/windows/kobodl.rc")
	set(CMAKE_RC_COMPILER_INIT windres)
	ENABLE_LANGUAGE(RC)
	SET(CMAKE_RC_COMPILE_OBJECT
		"<CMAKE_RC_COMPILER> <FLAGS> -O coff <DEFINES> -i <SOURCE> -o <OBJECT>")
	# windres reads the icon, but CMake does not scan .rc files for that
	set_source_files_properties(${RES_FILES} PROPERTIES OBJECT_DEPENDS
		"${KOBODELUXE_SOURCE_DIR}/icons/windows/kobodl.ico")
endif(MINGW)

add_executable(kobodl WIN32 MACOSX_BUNDLE ${sources} ${RES_FILES})
if(APPLE)
	set_target_properties(kobodl PROPERTIES
		OUTPUT_NAME "${KOBO_BUNDLE_NAME}"
		MACOSX_BUNDLE_BUNDLE_NAME "Kobo Deluxe"
		MACOSX_BUNDLE_GUI_IDENTIFIER "net.olofson.kobodeluxe"
		MACOSX_BUNDLE_BUNDLE_VERSION "${KOBO_BASE_VERSION}"
		MACOSX_BUNDLE_SHORT_VERSION_STRING "${VERSION_STRING}"
		MACOSX_BUNDLE_ICON_FILE "kobodl.icns"
		MACOSX_BUNDLE_COPYRIGHT "GPL-2.0-or-later")
	set(KOBO_ICNS "${KOBODELUXE_SOURCE_DIR}/icons/macos/kobodl.icns")
	if(EXISTS "${KOBO_ICNS}")
		target_sources(kobodl PRIVATE "${KOBO_ICNS}")
		set_source_files_properties("${KOBO_ICNS}" PROPERTIES
			MACOSX_PACKAGE_LOCATION "Resources")
	endif()
else()
	set_target_properties(kobodl PROPERTIES OUTPUT_NAME
		"kobodl${KOBO_EXE_SUFFIX}")
endif()

if(APPLE)
	target_sources(kobodl PRIVATE macos_hotkeys.c)
	target_link_libraries(kobodl "-framework CoreGraphics")
endif()

if(MINGW)
	# Avoid shipping (and mismatching) the GCC runtime DLLs
	target_link_options(kobodl PRIVATE -static-libgcc -static-libstdc++)
endif()

target_link_libraries(kobodl ${SDL_LIBRARY} ${SDLIMAGE_LIBRARY} ${KOBO_EXTRA_LIBRARIES})
#target_link_libraries(kobodl ${SDL2_LIBRARIES} ${SDL2IMAGE_LIBRARIES}
#	${AUDIALITY2_LIBRARIES} ${KOBO_EXTRA_LIBRARIES})

if(WIN32)
	target_link_libraries(kobodl winmm dxguid)
endif(WIN32)

# Release build: full optimization, no debug features, no debug info
set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")

# Maintainer build: No optimizations, lots of warnings, fail on warnings
set(f "-O1 -g -DDEBUG -Wall -Wwrite-strings -Wcast-align")
set(f "${f} -Waggregate-return")
set(f "${f} -fno-builtin -Wshadow")
set(f "${f} -Wmissing-declarations -Wdisabled-optimization")
set(fc "${f} -Wbad-function-cast -Wstrict-prototypes")
set(fc "${f} -Wdeclaration-after-statement -Wmissing-prototypes")
set(CMAKE_C_FLAGS_MAINTAINER "${fc} -Werror")
set(CMAKE_CXX_FLAGS_MAINTAINER "${f} -Werror")

# Debug build: Maintainer + extra debug features, don't fail on warnings
set(CMAKE_C_FLAGS_DEBUG ${fc})
set(CMAKE_CXX_FLAGS_DEBUG ${f})

set(CMAKE_EXTRA_INCLUDE_FILES stdio.h)
check_function_exists(snprintf		KOBO_HAVE_SNPRINTF)
check_function_exists(_snprintf		KOBO_HAVE__SNPRINTF)
check_function_exists(vsnprintf		KOBO_HAVE_VSNPRINTF)
check_function_exists(_vsnprintf	KOBO_HAVE__VSNPRINTF)

set(CMAKE_EXTRA_INCLUDE_FILES unistd.h)
check_function_exists(getegid		KOBO_HAVE_GETEGID)
check_function_exists(setgid		KOBO_HAVE_SETGID)

set(CMAKE_EXTRA_INCLUDE_FILES sys/types.h sys/stat.h unistd.h)
check_function_exists(stat		KOBO_HAVE_STAT)
check_function_exists(lstat		KOBO_HAVE_LSTAT)

set(CMAKE_EXTRA_INCLUDE_FILES)

if(NOT WIN32)
	set(KOBO_DATADIR "${CMAKE_INSTALL_PREFIX}/share/${KOBO_PACKAGE_NAME}")
	set(KOBO_USERDIR "HOME>>.${KOBO_PACKAGE_NAME}")
	set(KOBO_SYSCONFDIR "/etc")
else(NOT WIN32)
	# Program Files is not writable, so keep user data in %APPDATA%
	set(KOBO_USERDIR "APPDATA>>${KOBO_APPLICATION}")
endif(NOT WIN32)
set(KOBO_CONFIGFILE "${KOBO_PACKAGE_NAME}.cfg")

CHECK_C_SOURCE_COMPILES(
	"#include <sys/types.h>
	 #include <signal.h>
	 int main(void) {
	 	return *(signal(0,0))(0) == 1;
	 }"
	RETSIGTYPE_INT
)
if(RETSIGTYPE_INT)
	set(RETSIGTYPE int)
else(RETSIGTYPE_INT)
	set(RETSIGTYPE void)
endif(RETSIGTYPE_INT)
MESSAGE(STATUS "Signal handler return type: ${RETSIGTYPE}")

set(KOBODELUXE_AUTO_MESSAGE
	"This file is automatically generated. Do not edit!")
configure_file(${CMAKE_SOURCE_DIR}/buildconfig.h.cmake
	${CMAKE_BINARY_DIR}/include/buildconfig.h)

if(WIN32)
	# Ship the DLLs kobodl.exe needs. SDL.dll (sdl12-compat) loads SDL2.dll
	# at runtime, so that one is not in any import table and is added here.
	get_filename_component(KOBO_SDL_LIBDIR "${SDL_LIBRARY_TEMP}" DIRECTORY)
	find_file(KOBO_SDL2_DLL SDL2.dll
		HINTS "${KOBO_SDL_LIBDIR}/../bin" PATH_SUFFIXES bin REQUIRED)
	get_filename_component(KOBO_DLL_DIR "${KOBO_SDL2_DLL}" DIRECTORY)
	install(TARGETS kobodl DESTINATION "${KOBO_BIN_DIR}")
	find_program(KOBO_OBJDUMP NAMES
		${CMAKE_SYSTEM_PROCESSOR}-w64-mingw32-objdump objdump REQUIRED)
	install(CODE "
		set(KOBO_EXE \"$<TARGET_FILE:kobodl>\")
		set(KOBO_DLL_DIR \"${KOBO_DLL_DIR}\")
		set(KOBO_DEST \"\${CMAKE_INSTALL_PREFIX}/${KOBO_BIN_DIR}\")
		set(KOBO_OBJDUMP \"${KOBO_OBJDUMP}\")
		include(\"${KOBODELUXE_SOURCE_DIR}/cmake/BundleWindowsDlls.cmake\")
	")
	install(FILES "${KOBO_SDL2_DLL}" DESTINATION "${KOBO_BIN_DIR}")
elseif(APPLE)
	install(TARGETS kobodl BUNDLE DESTINATION "${KOBO_BIN_DIR}")
else()
	install(TARGETS kobodl DESTINATION "${KOBO_BIN_DIR}")
endif()
