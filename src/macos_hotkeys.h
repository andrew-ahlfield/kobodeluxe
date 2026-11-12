/*
------------------------------------------------------------
   Kobo Deluxe - macOS system keyboard shortcut blocking
------------------------------------------------------------
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

#ifndef KOBO_MACOS_HOTKEYS_H
#define KOBO_MACOS_HOTKEYS_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Turn the system wide keyboard shortcuts (Mission Control, Spaces,
 * Cmd+Tab and so on) off (block = 1) or back on (block = 0). Cheap to
 * call every frame; it only talks to the window server on a change.
 * Does nothing on other platforms.
 */
#ifdef __APPLE__
void macos_block_system_hotkeys(int block);
#else
static inline void macos_block_system_hotkeys(int block) { (void)block; }
#endif

#ifdef __cplusplus
}
#endif

#endif /* KOBO_MACOS_HOTKEYS_H */
