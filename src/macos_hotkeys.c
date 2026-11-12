/*
------------------------------------------------------------
   Kobo Deluxe - macOS system keyboard shortcut blocking
------------------------------------------------------------
 * Copyright (C) 2026 Andrew Ahlfield
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Kobo fires with Ctrl and steers with the arrow keys, and Ctrl+arrow is
 * Mission Control and Spaces switching on macOS, which the window server
 * acts on before the game ever sees the keys. There is no public API for
 * keeping them, so this uses the same private window server call as
 * remote desktop and game streaming clients. The window server puts the
 * shortcuts back when the process exits, even if it crashes.
 */

#include "macos_hotkeys.h"

#include <stdlib.h>
#include <CoreGraphics/CoreGraphics.h>

typedef int CGSConnectionID;

enum {
	KOBO_CGS_HOTKEYS_ENABLE = 0,
	KOBO_CGS_HOTKEYS_DISABLE = 1
};

extern CGSConnectionID CGSMainConnectionID(void);
extern CGError CGSSetGlobalHotKeyOperatingMode(CGSConnectionID cid,
		int mode);

static int blocked = 0;
static int broken = 0;
static int exit_hook = 0;

static void restore_at_exit(void)
{
	macos_block_system_hotkeys(0);
}

void macos_block_system_hotkeys(int block)
{
	block = !!block;
	if(broken || block == blocked)
		return;
	if(!exit_hook)
	{
		atexit(restore_at_exit);
		exit_hook = 1;
	}
	if(CGSSetGlobalHotKeyOperatingMode(CGSMainConnectionID(), block ?
			KOBO_CGS_HOTKEYS_DISABLE : KOBO_CGS_HOTKEYS_ENABLE) !=
			kCGErrorSuccess)
	{
		/* Don't retry every frame; the game still works without it */
		broken = 1;
		return;
	}
	blocked = block;
}
