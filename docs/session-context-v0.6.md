# v0.6 Continuation Context

Use this as the short handoff for future sessions.

## Stable Baselines

- v0.4 remains the monolithic/CDT-friendly baseline.
- v0.5 remains the first direct-FDC overlay baseline.
- v0.6 is the active DSK-only direct-FDC overlay baseline.
- The user runs the game with:

```basic
RUN"TETRIS.BIN"
```

## Current v0.6 Status

- Direct-FDC boot works.
- Direct-FDC runtime overlays work.
- Splash, title music, resident menu, gameplay, game over, and return-to-menu
  have all been tested during the v0.5/v0.6 work.
- The gameplay screen is mock-inspired and generated from
  `assets\new_gameplay_layout.jpg`.
- The menu code is resident again to remove the return-to-menu delay.
- Do not push experimental iterations unless the user explicitly asks.

## Current Build Metrics

- Resident payload load: `0x1000`
- Resident payload highest address: `0x3217`
- Resident payload bytes: 8728
- Resident payload sectors: 18
- Boot loader load/run: `0x0800`
- Boot loader size: 851 bytes
- Gameplay screen overlay: `0xC000`, 16384 bytes, 32 sectors
- Splash/title overlay: `0x5000`, 16175 bytes, 32 sectors
- Runtime font/text/tables: `0x5000`, 864 bytes, 2 sectors
- Gameplay music overlay: `0x9400`, 686 bytes, 2 sectors
- Menu/redefine-key code: resident, not overlaid

## Memory Planning

- About 5.5 KB guarded resident growth remains below the overlay workspace.
- The resident-menu decision cost 921 bytes versus the v0.5 menu-overlay build.
- Gameplay screen art intentionally uses screen RAM and is loaded only when
  gameplay starts.
- Future stage-specific assets should stay as overlays where possible.
- If resident code grows too much, candidates for overlaying are game-over,
  options/redefine, or non-gameplay UI paths.

## Next Good Improvements

- Tune the gameplay background if more screenshots show visual misalignment.
- Add a small overlay manifest to the build script if the number of segments
  grows beyond the current hard-coded layout.
- Split game-over or options screens into overlays if they become feature-heavy.
- Keep diagnostics available for future FDC changes.
