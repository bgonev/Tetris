# CPC Direct-FDC Overlay Loader Notes

These notes capture the reusable model from Tetris v0.5 for future CPC games.

## Design Goal

Keep only the always-needed game kernel resident. Load splash screens, title
music, menus, gameplay tables, and other stage-specific data from disk sectors
only when needed. This avoids keeping every asset and subsystem in RAM at once.

## Disk Layout

The DSK uses ordinary CPC data-format sectors:

```text
Sector IDs per track: C1 C6 C2 C7 C3 C8 C4 C9 C5
Sector size:          512 bytes
```

Current Tetris v0.5 hidden-sector layout:

```text
Track 20-21  resident game payload       -> 0x1000
Track 30-33  splash image + title music  -> 0x5000
Track 34     gameplay music              -> 0x9400
Track 35     runtime font/text/tables    -> 0x5000
Track 36     menu code overlay           -> 0x5400
```

The catalog-visible `TETRIS.BIN` is only the boot file. Everything else is read
from fixed sectors by the loader.

## Boot Loader

`tools\overlay_sector_loader_direct_fdc.s` is loaded and run at `0x0800`.

Responsibilities:

- Print `Sit down tightly while the game loads..`
- Set stack to `0xBFF0`.
- Turn on the drive motor through `0xFA7E`.
- Recalibrate and seek using the FDC command path.
- Read the resident payload into `0x1000`.
- Jump to the generated game run address.

The boot path keeps interrupts disabled during the payload transfer. Earlier
tests showed that allowing interrupts during this phase could corrupt or overrun
the load.

## Runtime Loader

`tools\runtime_overlay_loader.s` is linked into the resident game.

Public entry points:

```asm
_overlay_load_initial_segments
_overlay_load_runtime_font
_overlay_load_menu_code
_overlay_run_menu_code
```

Runtime segments are described as:

```asm
.dw destination
.db start_track
.db start_sector_index
.db sector_count
```

The loader restarts the motor/recalibrate path for each runtime overlay load and
stops the motor after a successful segment load.

## FDC Access Pattern

The loader talks to the CPC floppy controller directly:

- Motor control: `0xFA7E`
- FDC main status register: `0xFB7E`
- FDC data register: `0xFB7F`

Implemented commands:

- `0x07` recalibrate
- `0x0F` seek
- `0x08` sense interrupt status
- `0x46` read data, MFM

Important behavior discovered during testing:

- `sense interrupt status` may return `ST0=0x80` while no interrupt result is
  ready yet. Treat this as "keep polling", not as a hard failure.
- Track/sector diagnostic screens are valuable. The diagnostic build reported
  status bytes such as `ST 40 90 00 23 00 C1 02` while the read path was being
  corrected.
- Reading sectors works reliably with fixed track/sector ordering once seek
  polling and command/result byte timing are correct.

## Overlay Rules For Future Games

- Keep shared resident code small and stable.
- Put stage-specific code and data into sector-counted overlays.
- Keep each overlay load address explicit.
- Let overlays overwrite previous stage data when the previous stage is no
  longer needed.
- Keep the screen at `0xC000-0xFFFF` out of the general feature budget.
- Leave stack safety below `0xBFF0`, or deliberately move the stack if a future
  memory map requires it.
- If an overlay grows, increase its sector count in the build script. The build
  pads overlays and fails if the actual binary exceeds the reserved size.

## Current Reusable Scripts

- `tools\build_overlay_dsk.ps1`: official Tetris v0.5 overlay DSK builder.
- `tools\build_fdc_diagnostic_dsk.ps1`: single-track FDC diagnostic disk.
- `tools\overlay_sector_loader_direct_fdc.s`: direct-FDC boot loader template.
- `tools\runtime_overlay_loader.s`: resident runtime overlay loader template.
- `tools\menu_overlay.c`: example of C code compiled as a callable overlay.
