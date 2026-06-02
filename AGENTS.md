# Tetris CPC Project Context

This repository is an Amstrad CPC Tetris game built with CPCtelera.

## Paths

- Project root: `C:\Users\bgone\amstrad\Tetris`
- Shared CPCtelera root: `C:\Users\bgone\amstrad\cpctelera`
- Shared CPCtelera Cygwin path: `/cygdrive/c/Users/bgone/amstrad/cpctelera`
- Local Cygwin toolchain used by release script: `toolchains\cygwin64`

Do not re-clone CPCtelera inside this repo. `cfg/build_config.mk` defaults to
`CPCT_PATH ?= ../cpctelera`, and `tools/build_cpc_release.ps1` resolves the
shared path automatically.

## Build

Preferred release build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_cpc_release.ps1
```

Outputs:

- `dist\TETRIS.BIN`: AMSDOS-headered binary for direct `RUN"TETRIS.BIN"`.
- `dist\TETRIS.DSK`: WinAPE-ready disk image.
- If WinAPE locks `dist\TETRIS.DSK`, the script writes `dist\TETRIS-UPDATED.DSK`.

Known binary parameters after recent builds:

- Load address: `&4000`
- Run address: currently `&533E`
- DSK catalog entry: `TETRIS.BIN`

## Current Game Features

- CPCtelera native C/ASM project, MODE 0.
- 10x20 Tetris playfield.
- `CELL_WB 2`, `CELL_H 8`, `BOARD_X 10`, `BOARD_Y 16`, `PANEL_X 44`.
- Solid CPCtelera tile sprites for gameplay blocks.
- Compact MODE 0 sprite font for menu, side panel, game over, and dedication.
- Gameplay screen includes `for my daughter Marija` at the bottom.
- Splash screen includes small credit text: `Made by Bgonev, 2026`.
- Splash waits for any key or joystick fire before menu.
- Menu options: keyboard, joystick, redefine keys.
- Keyboard defaults: `O`/cursor-left, `P`/cursor-right, `Q`/cursor-up rotate,
  `A`/cursor-down, `SPACE` or `RETURN` hard drop.
- Joystick defaults: left/right/down movement, fire 1 rotate, up or fire 2 hard drop.

## Important Fixes Already Done

- Fixed default keys not working before redefine by initializing key IDs at runtime.
- Fixed L and mirrored-L tetromino rotation tables.
- Fixed active piece blinking by erasing/redrawing only when position or rotation changes.
- Fixed graphics distortion caused by CPC MODE/video memory mismatch by explicitly setting:
  `firmware_set_mode0()`, `cpct_setVideoMemoryPage(cpct_pageC0)`,
  `cpct_setVideoMemoryOffset(0)`, and `cpct_setVideoMode(0)`.
- Improved block ratio/resolution to solid MODE 0 block sprites.
- Added line-clear clink as a short AY noise accent without using firmware SOUND.

## Music / Sound

- Music is handled by `src/music.s` using direct AY register writes.
- The player does not use firmware `SOUND`, avoiding movement/clink interruptions.
- `_music_init_troika` starts title/splash music.
- `_music_init` starts gameplay music.
- `_music_play_frame` should be called once per frame after VSYNC.
- `_sfx_line_clear` overlays the clink through `sfx_timer`.
- Current active gameplay table is `korobeiniki_classic_data`, looped with `cp #70`.
- `troika_data` remains the intro/title tune.
- Older unused music tables may still exist in `src/music.s`; check actual `ld de, #...`
  pointer and loop constant before editing.

Do not claim exact copyrighted songs were implemented if source/licensing is not clear.
Past requests included Leb i Sol "Skopje" and the Macedonian anthem; those were handled
as original/inspired alternatives, not exact note-for-note reproductions.

## Main Files

- `src/main.c`: game logic, graphics, input, menu, splash flow, gameplay loop.
- `src/music.s`: direct AY music and clink SFX.
- `src/splash.s`, `src/splash.h`: generated MODE 0 splash asset.
- `tools/generate_splash_source.ps1`: creates splash source image with credit text.
- `tools/generate_splash_assets.ps1`: converts splash image to CPC MODE 0 data.
- `tools/build_cpc_release.ps1`: builds native output and creates AMSDOS BIN/DSK release.
- `cfg/build_config.mk`: CPCtelera project config.

## WinAPE Usage

Use:

```basic
RUN"TETRIS.BIN"
```

If `dist\TETRIS.DSK` cannot be overwritten during builds, close/eject the disk in WinAPE
or use the generated `dist\TETRIS-UPDATED.DSK`.
