/*
------------------------------------------------------------
   Kobo Deluxe - Gamepads through SDL2's game controller API
------------------------------------------------------------
 * Copyright (C) 2026 Andrew Ahlfield
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

#ifndef KOBO_GAMEPAD_H
#define KOBO_GAMEPAD_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * The game is written against SDL 1.2, whose joystick API numbers
 * buttons and axes however each driver happens to, so Start, the d-pad
 * and the face buttons land on different numbers for every pad and
 * platform. Every build ships sdl12-compat, which runs on SDL2, and
 * SDL2 has a game controller API with one standard layout and a
 * database of pads. This module finds the SDL2 library sdl12-compat
 * already loaded and reads the pads through it.
 *
 * With a real SDL 1.2, or an SDL2 without the API, gamepad_open()
 * returns 0 and the game falls back to the SDL 1.2 joystick.
 */

/* Logical gamepad buttons, as bits in what gamepad_poll() returns */
#define GP_UP		0x0001
#define GP_DOWN		0x0002
#define GP_LEFT		0x0004
#define GP_RIGHT	0x0008
#define GP_FIRE		0x0010	/* A, X, Y, shoulders, triggers */
#define GP_START	0x0020	/* Start */
#define GP_BACK		0x0040	/* B */
#define GP_MENU		0x0080	/* Back, View, Select, Share, minus */

/*
 * Start reading gamepads. Call after SDL_Init(). Returns 1 if SDL2's
 * game controller API is in use, 0 if not.
 */
int gamepad_open(void);
void gamepad_close(void);

/* Returns 1 between a successful gamepad_open() and gamepad_close() */
int gamepad_active(void);

/* Number of gamepads currently connected and open */
int gamepad_count(void);

/*
 * Returns 1 if the SDL 1.2 joystick with this index and name is a pad
 * this module reads, so the SDL 1.2 joystick path should leave it alone.
 */
int gamepad_handles_joystick(int index, const char *name);

/*
 * Read every connected pad and return the GP_* buttons held on any of
 * them. Picks up pads plugged in or pulled out since the last call.
 * Call once per frame, after the SDL event queue has been drained.
 */
unsigned gamepad_poll(void);

#ifdef __cplusplus
}
#endif

#endif /* KOBO_GAMEPAD_H */
