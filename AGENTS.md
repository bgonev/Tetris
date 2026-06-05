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

## Preferred v0.7 Build

Official v0.7 release build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_overlay_dsk.ps1
```

Outputs:

- `dist\TETRIS.DSK`: current v0.7 release disk.
- `dist\TETRIS-v0.7.DSK`: versioned v0.7 release disk.
- `dist\TETRIS.BIN`: AMSDOS-headered direct-FDC boot file for reference.
- `dist\TETRIS-v0.7.BIN`: versioned direct-FDC boot file.

Use:

```basic
RUN"TETRIS.BIN"
```

v0.7 is DSK-only. It uses hidden sectors and direct FDC access, so the overlay
strategy does not apply to CDT. Keep v0.4 as the monolithic/CDT-friendly build.

## Current v0.7 Overlay Layout

- Boot loader: load/run `0x0800`, direct FDC, catalog filename `TETRIS.BIN`.
- Resident payload: load `0x1000`, run `0x304F`, highest address `0x3C85`.
- Resident payload bytes: 11398, 23 sectors, tracks 20-22.
- Gameplay screen overlay: load `0xC000`, 16384 bytes, tracks 23-26.
- High-score sector: buffer `0x4E00`, 512 bytes, track 27.
- Splash/title overlay: load `0x5000`, 16175 bytes, tracks 30-33.
- Gameplay music overlay: load `0x9400`, 686 bytes, track 34.
- Runtime font/text/tables overlay: load `0x5000`, 886 bytes, track 35.
- Menu/redefine-key code: resident in the main payload, not an overlay.
- Screen RAM: `0xC000-0xFFFF`.

Current practical memory planning:

- Keep stage-specific data in overlays when possible.
- Gameplay screen art intentionally uses screen RAM and is loaded only when
  gameplay starts.
- High-score persistence uses one hidden sector and `0x4E00` as the RAM buffer.
- If resident code grows too much, candidates for overlaying are game-over,
  options/redefine, or future non-gameplay UI paths.

## Important v0.7 Loader Facts

- Boot and runtime loaders use FDC motor control at `0xFA7E`.
- FDC main status is read at `0xFB7E`; data is read/written at `0xFB7F`.
- Sector order is `C1 C6 C2 C7 C3 C8 C4 C9 C5`.
- Runtime overlay functions are in `tools\runtime_overlay_loader.s`.
- Boot loader template is `tools\overlay_sector_loader_direct_fdc.s`.
- Runtime high-score load is fatal on read failure; high-score save is
  non-fatal and returns to the game after attempting the write.
- The write path uses FDC command `0x45` and keeps the data loop tight so it can
  keep up with the controller.
- Treat `sense interrupt status` result `ST0=0x80` as "not ready yet"; keep
  polling instead of failing.
- Keep interrupts disabled through the boot payload transfer.
- The FDC diagnostic builder is `tools\build_fdc_diagnostic_dsk.ps1`.

## Current Game Features

- CPCtelera native C/ASM project, MODE 0.
- 10x20 Tetris playfield.
- `CELL_WB 2`, `CELL_H 8`, `BOARD_X 30`, `BOARD_Y 20`.
- Solid CPCtelera tile sprites for gameplay blocks.
- Mock-inspired gameplay screen generated from `assets\new_gameplay_layout.jpg`.
- Green dome treatment in the gameplay tower.
- Compact left-aligned gameplay HUD:
  `SCORE 00000`, `LEVEL 001`, `LINES 0000`.
- Compact MODE 0 sprite font for menu, HUD, game over, and high scores.
- Loader message is centered as `For my daughter Marija`.
- Splash screen includes small credit text: `Made by Bgonev, 2026`.
- Splash waits for any key or joystick fire before menu.
- Game-over screen has animated `GAME OVER` text and a persistent high-score
  table.
- Default high-score table starts with `MARIJA 05000`.
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
- Moved splash/title data, gameplay screen art, music tables, runtime
  text/tables, and high-score persistence into overlays/hidden sectors.
- Moved menu/redefine-key code back into resident RAM for v0.6 and later to
  remove the game-over to menu reload delay.
- Reintroduced game-over animation while the high-score table and name-entry
  prompt are active.

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

- `src/main.c`: game logic, graphics, input, splash flow, gameplay loop, high scores.
- `src/music.s`: direct AY music and clink SFX source.
- `src/splash.s`, `src/splash.h`: generated MODE 0 splash asset.
- `tools/build_overlay_dsk.ps1`: official v0.7 overlay DSK release builder.
- `tools/build_cpc_release.ps1`: older non-overlay release builder.
- `tools/overlay_sector_loader_direct_fdc.s`: direct-FDC boot loader template.
- `tools/runtime_overlay_loader.s`: direct-FDC runtime overlay loader template.
- `tools/generate_gameplay_background.ps1`: gameplay screen overlay generator.
- `tools/build_fdc_diagnostic_dsk.ps1`: FDC diagnostic disk builder.
- `docs/overlay-fdc-loader.md`: reusable overlay/FDC method notes.
- `docs/session-context-v0.7.md`: future-session context.

## Future ULIfAC Note

ULIfAC WiFi plus a relay server may be feasible for online features later, but
WiFi should be treated as a gameplay-only phase. Do not perform hidden-sector
overlay loads or high-score disk saves while ULIfAC WiFi is active unless the
storage/WiFi mode-switching path has been proven.

## WinAPE Usage

Use:

```basic
RUN"TETRIS.BIN"
```

If `dist\TETRIS.DSK` cannot be overwritten during builds, close/eject the disk
in WinAPE before rebuilding.
