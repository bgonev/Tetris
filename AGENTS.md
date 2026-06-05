# Tetris CPC Project Context

This repository is an Amstrad CPC Tetris game built with CPCtelera.

## Paths

- Project root: `C:\Users\bgone\amstrad\Tetris`
- Shared CPCtelera root: `C:\Users\bgone\amstrad\cpctelera`
- Shared CPCtelera Cygwin path: `/cygdrive/c/Users/bgone/amstrad/cpctelera`
- Local Cygwin toolchain used by release scripts: `toolchains\cygwin64`

Do not re-clone CPCtelera inside this repo. `cfg/build_config.mk` defaults to
`CPCT_PATH ?= ../cpctelera`, and the build scripts resolve the shared path
automatically.

## Preferred v0.6 Build

Official v0.6 release build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_overlay_dsk.ps1
```

Outputs:

- `dist\TETRIS.DSK`: current v0.6 release disk.
- `dist\TETRIS-v0.6.DSK`: versioned v0.6 release disk.
- `dist\TETRIS.BIN`: AMSDOS-headered direct-FDC boot file for reference.
- `dist\TETRIS-v0.6.BIN`: versioned direct-FDC boot file.

Use:

```basic
RUN"TETRIS.BIN"
```

v0.6 is DSK-only. It uses hidden sectors and direct FDC access, so the overlay
strategy does not apply to CDT. Keep v0.4 as the monolithic/CDT-friendly build.

## Current v0.6 Overlay Layout

- Boot loader: load/run `0x0800`, direct FDC, catalog filename `TETRIS.BIN`.
- Resident payload: load `0x1000`, latest highest address about `0x3217`.
- Payload sectors: tracks 20-21.
- Gameplay screen overlay: load `0xC000`, tracks 22-25.
- Splash/title overlay: load `0x5000`, tracks 30-33.
- Gameplay music overlay: load `0x9400`, track 34.
- Runtime font/text/tables overlay: load `0x5000`, track 35.
- Menu/redefine-key code: resident in the main payload, not an overlay.
- Screen RAM: `0xC000-0xFFFF`.

Current practical memory planning:

- About 5.5 KB safe resident growth remains below the overlay workspace.
- Menu return from game over is immediate because the menu code is resident.
- Stage-specific data should still go into overlays when possible.
- About 20-25 KB can be used with deliberate overlay reuse.
- About 35 KB is theoretically usable across split regions if low/high RAM is
  managed carefully.

## Important v0.6 Loader Facts

- Boot and runtime loaders use FDC motor control at `0xFA7E`.
- FDC main status is read at `0xFB7E`; data is read/written at `0xFB7F`.
- Sector order is `C1 C6 C2 C7 C3 C8 C4 C9 C5`.
- Treat `sense interrupt status` result `ST0=0x80` as "not ready yet"; keep
  polling instead of failing.
- Keep interrupts disabled through the boot payload transfer.
- Runtime overlay functions are in `tools\runtime_overlay_loader.s`.
- Boot loader template is `tools\overlay_sector_loader_direct_fdc.s`.
- The FDC diagnostic builder is `tools\build_fdc_diagnostic_dsk.ps1`.

## Current Game Features

- CPCtelera native C/ASM project, MODE 0.
- 10x20 Tetris playfield.
- `CELL_WB 2`, `CELL_H 8`, `BOARD_X 10`, `BOARD_Y 16`, `PANEL_X 44`.
- Solid CPCtelera tile sprites for gameplay blocks.
- Mock-inspired gameplay screen generated from `assets\new_gameplay_layout.jpg`.
- Compact MODE 0 sprite font for menu, side panel, game over, and gameplay labels.
- Loader message is centered as `For my daughter Marija`.
- Splash screen includes small credit text: `Made by Bgonev, 2026`.
- Splash waits for any key or joystick fire before menu.
- Menu options: keyboard, joystick, redefine keys.
- Keyboard defaults: `O`/cursor-left, `P`/cursor-right, `Q`/cursor-up rotate,
  `A`/cursor-down, `SPACE` or `RETURN` hard drop.
- Joystick defaults: left/right/down movement, fire 1 rotate, up or fire 2 hard
  drop.

## Important Fixes Already Done

- Fixed default keys not working before redefine by initializing key IDs at runtime.
- Fixed L and mirrored-L tetromino rotation tables.
- Fixed active piece blinking by erasing/redrawing only when position or rotation changes.
- Fixed graphics distortion caused by CPC MODE/video memory mismatch by explicitly setting:
  `firmware_set_mode0()`, `cpct_setVideoMemoryPage(cpct_pageC0)`,
  `cpct_setVideoMemoryOffset(0)`, and `cpct_setVideoMode(0)`.
- Improved block ratio/resolution to solid MODE 0 block sprites.
- Added line-clear clink as a short AY noise accent without using firmware SOUND.
- Moved splash/title data, gameplay screen art, music tables, and runtime
  text/tables into overlays.
- Moved menu/redefine-key code back into resident RAM for v0.6 to remove the
  game-over to menu reload delay.

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

- `src/main.c`: game logic, graphics, input, splash flow, gameplay loop.
- `src/music.s`: direct AY music and clink SFX source.
- `src/splash.s`, `src/splash.h`: generated MODE 0 splash asset.
- `tools/build_overlay_dsk.ps1`: official v0.6 overlay DSK release builder.
- `tools/build_cpc_release.ps1`: older non-overlay release builder.
- `tools/overlay_sector_loader_direct_fdc.s`: direct-FDC boot loader template.
- `tools/runtime_overlay_loader.s`: direct-FDC runtime overlay loader template.
- `tools/generate_gameplay_background.ps1`: gameplay screen overlay generator.
- `tools/build_fdc_diagnostic_dsk.ps1`: FDC diagnostic disk builder.
- `docs/overlay-fdc-loader.md`: reusable overlay/FDC method notes.
- `docs/session-context-v0.6.md`: future-session context.

## WinAPE Usage

Use:

```basic
RUN"TETRIS.BIN"
```

If `dist\TETRIS.DSK` cannot be overwritten during builds, close/eject the disk
in WinAPE before rebuilding.
