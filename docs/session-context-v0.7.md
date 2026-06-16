# v0.7 Continuation Context

Use this as the short handoff for future sessions.

## Stable Baselines

- v0.4 remains the monolithic/CDT-friendly baseline.
- v0.5 remains the first direct-FDC overlay baseline.
- v0.6 remains the mock gameplay screen/resident menu baseline.
- v0.7 is the active DSK-only direct-FDC overlay baseline.
- The user runs the game with:

```basic
RUN"TETRIS.BIN"
```

## Current v0.7 Status

- Direct-FDC boot works.
- Direct-FDC runtime overlays work.
- Direct-FDC high-score sector read/write is implemented and tested on real
  CPC 464 + ULIfAC USB after the patched write-loop fix.
- Splash, title music, resident menu, gameplay, game over, high-score table,
  name entry, and return-to-menu have been tested during v0.7 work.
- The gameplay screen is generated from `assets\new_gameplay_layout.jpg`.
- The gameplay tower dome is green in v0.7.
- The HUD is compact and left-aligned with a 5-digit score.
- Gameplay pieces use a shuffled 7-piece bag seeded from player timing, so
  fresh games no longer use the same deterministic piece order.
- Loader, splash, menu, gameplay, and game-over/high-score screens use a black
  background and black hardware border in normal operation.
- Do not push experimental iterations unless the user explicitly asks.

## Current Build Metrics

- Boot loader load/run: `0x0800`
- Boot loader size: 909 bytes
- Resident payload load: `0x1000`
- Resident payload run: `0x31BA`
- Resident payload highest address: `0x3E7B`
- Resident payload bytes: 11900
- Resident payload sectors: 24
- Resident payload tracks: 20-22
- Gameplay screen overlay: `0xC000`, 16384 bytes, 32 sectors, tracks 23-26
- High-score sector: `0x4E00`, 512 bytes, 1 sector, track 27
- Splash/title overlay: `0x5000`, 16175 bytes, 32 sectors, tracks 30-33
- Gameplay music overlay: `0x9400`, 686 bytes, 2 sectors, track 34
- Runtime font/text/tables: `0x5000`, 886 bytes, 2 sectors, track 35
- Menu/redefine-key code: resident, not overlaid

## High-Score Details

- RAM buffer: `0x4E00`
- Magic: `HS07`
- Version byte: `2`
- Entry count: `5`
- Entry format: 7-byte uppercase name + 5-byte ASCII score
- Default table:
  - `MARIJA 05000`
  - `MEGLENA 00870`
  - `MAKSIM 00640`
  - `BOJANA 00420`
  - `BORO 00250`
- Save failures are non-fatal. If save behavior regresses, inspect the
  `fdc_write_current_sector` timing loop in `tools\runtime_overlay_loader.s`.
- ULIfAC write behavior is documented in
  `docs\ulifac-fdc-write-notes.md`. Critical rule: during `WRITE DATA`
  execution, if `RQM=1` and `EXM=1`, feed data even if `DIO=1`. Do not read
  the FDC data register while `EXM=1` on ULIfAC.

## Memory Planning

- Keep stage-specific assets in overlays where possible.
- The high-score sector uses only a 512-byte buffer at `0x4E00`.
- Gameplay screen art intentionally uses screen RAM and is loaded only when
  gameplay starts.
- If resident code grows too much, candidates for overlaying are game-over,
  options/redefine, or future non-gameplay UI paths.

## Future ULIfAC Note

ULIfAC WiFi plus a relay server may be feasible later. Because ULIfAC USB/FDC
storage and WiFi share a serial-side path, any future online mode should use
strict phases:

```text
load all needed overlays first
play online with no disk/overlay/high-score writes
close WiFi or restore storage mode
then save or load sectors if needed
```

Do not attempt hidden-sector overlay loads or high-score saves while WiFi is
active until mode switching has been proven.

## Next Good Improvements

- Keep the patched v0.7 release disk as the baseline for ULIfAC high-score
  persistence.
- If the HUD still needs visual tuning, adjust only `LEFT_PANEL_X` and
  `HUD_VALUE_X` in `src\main.c`.
- Add a small overlay manifest to the build script if the number of segments
  grows beyond the current hard-coded layout.
- Keep diagnostics available for future FDC changes.
