#ifndef TETRIS_SPLASH_H
#define TETRIS_SPLASH_H

#include <cpctelera.h>

#define SPLASH_W_BYTES 80
#define SPLASH_HEIGHT 200

#if OVERLAY_SPLASH
#define SPLASH_OVERLAY_ADDRESS ((const u8*)0x5000)
#define splash_img SPLASH_OVERLAY_ADDRESS
#else
extern const u8 splash_img[SPLASH_W_BYTES * SPLASH_HEIGHT];
#endif

#endif
