# v0.5 Continuation Context

Use this as the short handoff for future sessions.

## Stable Baseline

- v0.4 remains the monolithic/CDT-friendly baseline.
- v0.5 is now the DSK-only direct-FDC overlay baseline.
- The user runs the game with:

```basic
RUN"TETRIS.BIN"
```

## Current v0.5 Status

- Direct-FDC boot works.
- Direct-FDC runtime overlays work.
- Splash, title music, menu, gameplay, game over, and return-to-menu have all
  been tested by the user.
- The menu return has a small delay, now improved by reducing the menu overlay
  from 8 sectors to 3 sectors.
- Do not push experimental iterations unless the user explicitly asks.

## Current Build Metrics

- Resident payload load: `0x1000`
- Resident payload highest address: `0x2E1C`
- Resident payload bytes: 7709
- Resident payload sectors: 16
- Boot loader load/run: `0x0800`
- Boot loader size: 861 bytes
- Splash/title overlay: `0x5000`, 16175 bytes, 32 sectors
- Runtime font/text/tables: `0x5000`, 864 bytes, 2 sectors
- Menu code overlay: `0x5400`, 966 bytes, 3 sectors
- Gameplay music overlay: `0x9400`, 686 bytes, 2 sectors

## Memory Planning

- About 7 KB safe resident growth remains below the overlay workspace.
- About 12 KB continuous overlay space is immediately available below gameplay
  music without disturbing current layout.
- About 20-25 KB can be used with deliberate overlay reuse.
- About 35 KB is theoretically usable across split regions if low/high RAM is
  managed carefully.

## Next Good Improvements

- Move more gameplay-only code into overlays if resident growth becomes tight.
- Split game-over or options screens into their own overlays if they grow.
- Add a small overlay manifest to the build script if the number of segments
  grows beyond the current hard-coded layout.
- Keep diagnostics available for future FDC changes.
