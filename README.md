# Tetris v0.7

Amstrad CPC `MODE 0` Tetris built with CPCtelera.

Version 0.7 is a DSK-only direct-FDC overlay release. The visible disk entry
point is a small boot file named `TETRIS.BIN`; the resident game payload,
runtime overlays, and persistent high-score sector are stored in fixed hidden
sectors on the DSK. The current v0.7 release includes the ULIfAC raw-FDC write
fix for high-score saves and a shuffled 7-piece gameplay randomizer.

Run in WinAPE or on a CPC disk setup:

```basic
RUN"TETRIS.BIN"
```

## Build

The project expects the shared CPCtelera installation at:

```text
C:\Users\bgone\amstrad\cpctelera
```

Build the official v0.7 overlay disk with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_overlay_dsk.ps1
```

Main outputs:

- `dist/TETRIS.DSK`: current v0.7 release disk.
- `dist/TETRIS-v0.7.DSK`: versioned v0.7 release disk.
- `dist/TETRIS.BIN`: AMSDOS-headered direct-FDC boot file for reference.
- `dist/TETRIS-v0.7.BIN`: versioned boot file.

There is no v0.7 CDT because the v0.7 memory strategy depends on disk sector
overlays. Keep v0.4 as the monolithic/CDT-friendly baseline.

The older non-overlay release script remains available for comparison. Its
outputs go under `dist\nonoverlay\` so it does not overwrite the official
overlay release:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_cpc_release.ps1
```

## v0.7 Memory Strategy

- Resident game code links at `0x1000`.
- Boot loader runs at `0x0800`.
- Splash/title data, gameplay screen art, gameplay music, runtime text/tables,
  and the high-score sector are loaded from hidden sectors only when needed.
- Menu and redefine-key code are resident to keep menu return immediate.
- Screen RAM remains at `0xC000-0xFFFF`.
- Current resident payload ends at `0x3E96`, leaving guarded resident growth
  below the overlay workspace and more room through overlays.

Details are documented in:

- `docs/v0.7-release.md`
- `docs/overlay-fdc-loader.md`
- `docs/ulifac-fdc-write-notes.md`
- `docs/session-context-v0.7.md`

## Features

- Native CPCtelera C/ASM project in `MODE 0`.
- Direct-FDC boot and runtime sector overlays.
- Full-screen CPC-style splash/title picture before the menu.
- Loader message centered as `For my daughter Marija`.
- Splash waits for any key or joystick fire while playing a 3-channel
  Troika-style loop.
- Mock-inspired gameplay screen overlay generated from
  `assets/new_gameplay_layout.jpg`.
- Green dome treatment on the gameplay tower.
- Compact left-aligned HUD with 5-digit score:
  `SCORE 00000`, `LEVEL 001`, `LINES 0000`.
- 10x20 Tetris playfield with solid CPCtelera tile sprites.
- Gameplay pieces use a shuffled 7-piece bag, seeded from player timing, so
  fresh games no longer start with the same deterministic piece order.
- Compact sprite font for menu, panel, game over, and gameplay labels.
- Animated coloured `Z32X Tetris` menu title.
- Animated `GAME OVER` screen with persistent five-entry high-score table.
- High-score table is loaded from and saved to a hidden DSK sector.
- High-score saving has been tested on real CPC 464 + ULIfAC USB. The runtime
  write loop handles ULIfAC's `MSR F0` write-execution behavior by feeding data
  while `RQM=1` and `EXM=1`, ignoring `DIO` in that phase.
- Default high-score leader: `MARIJA 05000`.
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

The gameplay background overlay is generated during the release build with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\generate_gameplay_background.ps1
```
