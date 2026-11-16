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

/*
 * No SDL headers here: the SDL 1.2 and SDL2 headers share names, and the
 * few SDL2 calls this needs are looked up at run time with their own
 * prototypes below.
 */

#include "gamepad.h"
#include "logger.h"

#include <stdint.h>
#include <string.h>

#ifdef _WIN32
# include <windows.h>
#else
# include <dlfcn.h>
# ifdef __APPLE__
#  include <mach-o/dyld.h>
# endif
#endif

/* SDL2 values, from SDL_gamecontroller.h and SDL.h */
#define SDL2_INIT_GAMECONTROLLER	0x00002000u

enum {
	AXIS_LEFTX, AXIS_LEFTY, AXIS_RIGHTX, AXIS_RIGHTY,
	AXIS_TRIGGERLEFT, AXIS_TRIGGERRIGHT
};

enum {
	BTN_A, BTN_B, BTN_X, BTN_Y, BTN_BACK, BTN_GUIDE, BTN_START,
	BTN_LEFTSTICK, BTN_RIGHTSTICK, BTN_LEFTSHOULDER, BTN_RIGHTSHOULDER,
	BTN_DPAD_UP, BTN_DPAD_DOWN, BTN_DPAD_LEFT, BTN_DPAD_RIGHT,
	BTN_MISC1	/* Share, Capture, Mic */
};

/*
 * Left stick to d-pad. A direction comes on past half way and goes off
 * again below a third, so a stick resting near the edge, or one that
 * drifts, can't chatter between the two.
 */
#define STICK_ON	16384
#define STICK_OFF	10000

/* Triggers read 0 at rest and 32767 fully pulled */
#define TRIGGER_ON	16384

#define MAX_PADS	8

/* Look for newly plugged in pads this often, in calls to gamepad_poll() */
#define RESCAN_INTERVAL	30

typedef struct gc_t gc_t;
typedef struct js_t js_t;

static struct {
	int (*InitSubSystem)(uint32_t flags);
	void (*QuitSubSystem)(uint32_t flags);
	int (*NumJoysticks)(void);
	int (*IsGameController)(int index);
	const char *(*JoystickNameForIndex)(int index);
	int32_t (*JoystickGetDeviceInstanceID)(int index);
	gc_t *(*GameControllerOpen)(int index);
	void (*GameControllerClose)(gc_t *gc);
	int (*GameControllerGetAttached)(gc_t *gc);
	js_t *(*GameControllerGetJoystick)(gc_t *gc);
	int32_t (*JoystickInstanceID)(js_t *js);
	const char *(*GameControllerName)(gc_t *gc);
	void (*GameControllerUpdate)(void);
	int16_t (*GameControllerGetAxis)(gc_t *gc, int axis);
	uint8_t (*GameControllerGetButton)(gc_t *gc, int button);
} sdl2;

typedef struct
{
	gc_t	*gc;
	int32_t	id;	/* SDL2 joystick instance ID */
	int	sx, sy;	/* Left stick as a d-pad: -1, 0 or 1 */
} pad_t;

static pad_t pads[MAX_PADS];
static int npads = 0;
static int active = 0;
static int rescan_countdown = 0;


/* The SDL2 library sdl12-compat loaded, without loading one ourselves */
#ifdef _WIN32
static void *find_sdl2(void)
{
	return (void *)GetModuleHandleA("SDL2.dll");
}

static void *sym(void *lib, const char *name)
{
	FARPROC f = GetProcAddress((HMODULE)lib, name);
	void *p;
	memcpy(&p, &f, sizeof(p));
	return p;
}
#else
static void *find_sdl2(void)
{
# ifdef __APPLE__
	/* Loaded by path from the app bundle, so look the path up */
	uint32_t i, n = _dyld_image_count();
	for(i = 0; i < n; ++i)
	{
		const char *path = _dyld_get_image_name(i);
		const char *base = path ? strrchr(path, '/') : NULL;
		base = base ? base + 1 : path;
		if(base && strncmp(base, "libSDL2", 7) == 0)
		{
			void *lib = dlopen(path, RTLD_LAZY | RTLD_NOLOAD);
			if(lib)
				return lib;
		}
	}
	return NULL;
# else
	static const char *names[] = {
		"libSDL2-2.0.so.0", "libSDL2-2.0.so", "libSDL2.so", NULL
	};
	int i;
	for(i = 0; names[i]; ++i)
	{
		void *lib = dlopen(names[i], RTLD_LAZY | RTLD_NOLOAD);
		if(lib)
			return lib;
	}
	return NULL;
# endif
}

static void *sym(void *lib, const char *name)
{
	return dlsym(lib, name);
}
#endif


static int load_sdl2(void)
{
	void *lib = find_sdl2();
	if(!lib)
		return 0;

	/*
	 * Assigning through memcpy() keeps ISO C quiet about converting
	 * between object and function pointers.
	 */
#define LOAD(field, name)					\
	{							\
		void *p = sym(lib, name);			\
		if(!p)						\
			return 0;				\
		memcpy(&sdl2.field, &p, sizeof(p));		\
	}
	LOAD(InitSubSystem, "SDL_InitSubSystem")
	LOAD(QuitSubSystem, "SDL_QuitSubSystem")
	LOAD(NumJoysticks, "SDL_NumJoysticks")
	LOAD(IsGameController, "SDL_IsGameController")
	LOAD(JoystickNameForIndex, "SDL_JoystickNameForIndex")
	LOAD(JoystickGetDeviceInstanceID, "SDL_JoystickGetDeviceInstanceID")
	LOAD(GameControllerOpen, "SDL_GameControllerOpen")
	LOAD(GameControllerClose, "SDL_GameControllerClose")
	LOAD(GameControllerGetAttached, "SDL_GameControllerGetAttached")
	LOAD(GameControllerGetJoystick, "SDL_GameControllerGetJoystick")
	LOAD(JoystickInstanceID, "SDL_JoystickInstanceID")
	LOAD(GameControllerName, "SDL_GameControllerName")
	LOAD(GameControllerUpdate, "SDL_GameControllerUpdate")
	LOAD(GameControllerGetAxis, "SDL_GameControllerGetAxis")
	LOAD(GameControllerGetButton, "SDL_GameControllerGetButton")
#undef LOAD
	return 1;
}


static void drop_pad(int i)
{
	log_printf(ULOG, "Gamepad disconnected.\n");
	sdl2.GameControllerClose(pads[i].gc);
	pads[i] = pads[--npads];
}


static int is_open(int32_t id)
{
	int i;
	for(i = 0; i < npads; ++i)
		if(pads[i].id == id)
			return 1;
	return 0;
}


static void scan(void)
{
	int i, n;

	for(i = npads - 1; i >= 0; --i)
		if(!sdl2.GameControllerGetAttached(pads[i].gc))
			drop_pad(i);

	n = sdl2.NumJoysticks();
	for(i = 0; i < n && npads < MAX_PADS; ++i)
	{
		gc_t *gc;
		if(!sdl2.IsGameController(i))
			continue;
		if(is_open(sdl2.JoystickGetDeviceInstanceID(i)))
			continue;
		gc = sdl2.GameControllerOpen(i);
		if(!gc)
			continue;
		pads[npads].gc = gc;
		pads[npads].id = sdl2.JoystickInstanceID(
				sdl2.GameControllerGetJoystick(gc));
		pads[npads].sx = pads[npads].sy = 0;
		log_printf(ULOG, "Gamepad connected: %s\n",
				sdl2.GameControllerName(gc) ?
				sdl2.GameControllerName(gc) : "(unnamed)");
		++npads;
	}
}


int gamepad_open(void)
{
	if(active)
		return 1;
	if(!load_sdl2())
	{
		log_printf(VLOG, "SDL2 game controller API not found; using"
				" SDL 1.2 joysticks only.\n");
		return 0;
	}
	if(sdl2.InitSubSystem(SDL2_INIT_GAMECONTROLLER) < 0)
	{
		log_printf(WLOG, "Could not start SDL2 game controllers.\n");
		return 0;
	}
	active = 1;
	npads = 0;
	scan();
	rescan_countdown = RESCAN_INTERVAL;
	return 1;
}


void gamepad_close(void)
{
	if(!active)
		return;
	while(npads)
		sdl2.GameControllerClose(pads[--npads].gc);
	sdl2.QuitSubSystem(SDL2_INIT_GAMECONTROLLER);
	active = 0;
}


int gamepad_active(void)
{
	return active;
}


int gamepad_count(void)
{
	return active ? npads : 0;
}


int gamepad_handles_joystick(int index, const char *name)
{
	const char *n2;
	if(!active || index < 0 || index >= sdl2.NumJoysticks())
		return 0;
	if(!sdl2.IsGameController(index))
		return 0;
	/*
	 * sdl12-compat lists SDL2's joysticks in SDL2's order, but don't
	 * bet the controls on that: if the names disagree, claim it, so
	 * the two paths can't both read one pad.
	 */
	n2 = sdl2.JoystickNameForIndex(index);
	if(name && n2 && strcmp(name, n2) != 0)
		log_printf(WLOG, "SDL 1.2 joystick %d is '%s', but SDL2 calls"
				" it '%s'.\n", index, name, n2);
	return 1;
}


/* -1, 0 or 1, with hysteresis around the previous value */
static int stick(int prev, int v)
{
	if(v >= STICK_ON)
		return 1;
	if(v <= -STICK_ON)
		return -1;
	if(v > -STICK_OFF && v < STICK_OFF)
		return 0;
	return prev;
}


unsigned gamepad_poll(void)
{
	unsigned held = 0;
	int i;

	if(!active)
		return 0;

	if(--rescan_countdown <= 0)
	{
		scan();
		rescan_countdown = RESCAN_INTERVAL;
	}
	sdl2.GameControllerUpdate();

	for(i = 0; i < npads; ++i)
	{
		pad_t *p = &pads[i];
		gc_t *gc = p->gc;
#define B(b)	sdl2.GameControllerGetButton(gc, b)
#define A(a)	sdl2.GameControllerGetAxis(gc, a)
		p->sx = stick(p->sx, A(AXIS_LEFTX));
		p->sy = stick(p->sy, A(AXIS_LEFTY));

		if(B(BTN_DPAD_UP) || p->sy < 0)
			held |= GP_UP;
		if(B(BTN_DPAD_DOWN) || p->sy > 0)
			held |= GP_DOWN;
		if(B(BTN_DPAD_LEFT) || p->sx < 0)
			held |= GP_LEFT;
		if(B(BTN_DPAD_RIGHT) || p->sx > 0)
			held |= GP_RIGHT;

		if(B(BTN_A) || B(BTN_X) || B(BTN_Y) ||
				B(BTN_LEFTSHOULDER) || B(BTN_RIGHTSHOULDER) ||
				A(AXIS_TRIGGERLEFT) >= TRIGGER_ON ||
				A(AXIS_TRIGGERRIGHT) >= TRIGGER_ON)
			held |= GP_FIRE;
		if(B(BTN_B))
			held |= GP_BACK;
		if(B(BTN_START))
			held |= GP_START;
		if(B(BTN_BACK) || B(BTN_MISC1))
			held |= GP_MENU;
#undef B
#undef A
	}
	return held;
}
