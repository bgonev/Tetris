# Tetris v0.5

Amstrad CPC `MODE 0` Tetris built with CPCtelera.

Version 0.5 is a DSK-only overlay release. The visible disk entry point is a
small direct-FDC boot file named `TETRIS.BIN`; the resident game payload and
runtime overlays are stored in fixed hidden sectors on the DSK.

Run in WinAPE or on a CPC disk setup:

```basic
RUN"TETRIS.BIN"
```

## Build

The project expects the shared CPCtelera installation at:

```text
C:\Users\bgone\amstrad\cpctelera
```

Build the official v0.5 overlay disk with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_overlay_dsk.ps1
```

Main outputs:

- `dist/TETRIS.DSK`: current v0.5 release disk.
- `dist/TETRIS-v0.5.DSK`: versioned v0.5 release disk.
- `dist/TETRIS.BIN`: AMSDOS-headered direct-FDC boot file for reference.
- `dist/TETRIS-v0.5.BIN`: versioned boot file.

There is no v0.5 CDT because the v0.5 memory strategy depends on disk sector
overlays. Keep v0.4 as the monolithic/CDT-friendly baseline.

The older non-overlay release script remains available for comparison. Its
outputs go under `dist\nonoverlay\` so it does not overwrite the official v0.5
overlay release:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_cpc_release.ps1
```

## v0.5 Memory Strategy

- Resident game code links at `0x1000`.
- Boot loader runs at `0x0800`.
- Splash/title data, gameplay music, runtime text/tables, and menu code are
  loaded from hidden sectors only when needed.
- Screen RAM remains at `0xC000-0xFFFF`.
- Current resident payload ends at `0x2E1C`, leaving about 7 KB of guarded
  resident growth and much more room through overlays.

Details are documented in:

- `docs/v0.5-release.md`
- `docs/overlay-fdc-loader.md`
- `docs/session-context-v0.5.md`

## Features

- Native CPCtelera C/ASM project in `MODE 0`.
- Full-screen CPC-style splash/title picture before the menu.
- Splash waits for any key or joystick fire while playing a 3-channel
  Troika-style loop.
- 10x20 Tetris playfield with solid CPCtelera tile sprites.
- Compact sprite font for menu, panel, game over, dedication, and overlays.
- Animated coloured `Z32X Tetris` menu title.
- Centered 2x `GAME OVER` text with rapidly rotating character colours.
- Gameplay screen includes `for my daughter Marija`.
- Score counter: single/double/triple/Tetris clears score 40/100/300/1200
  points multiplied by current level.
- Level progression starts at level 1, caps at level 100, and advances every
  10 cleared lines.
- Menu options: keyboard, joystick, redefine keys.
- Keyboard defaults: `O`/cursor-left, `P`/cursor-right, `Q`/cursor-up rotate,
  `A`/cursor-down, `SPACE` or `RETURN` hard drop.
- Joystick defaults: left/right/down movement, fire 1 rotate, up or fire 2 hard
  drop.
- Direct AY music player with line-clear clink mixed as a short noise accent.

## Project Notes

The older Locomotive BASIC prototype is still kept as `TETRIS.BAS`, and the
previous hand-written Z80 prototype is kept as `src/tetris_mc.asm`.

Splash source assets are generated with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\generate_splash_source.ps1
powershell -ExecutionPolicy Bypass -File .\tools\generate_splash_assets.ps1
```
