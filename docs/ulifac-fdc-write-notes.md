# ULIfAC Direct-FDC Write Notes

These notes capture the raw-FDC high-score save fix found during Tetris v0.7
testing on a real CPC 464 with ULIfAC USB storage.

## Short Rule

When a `WRITE DATA` command is in execution phase on ULIfAC:

```text
MSR bit 7 RQM = 1
MSR bit 5 EXM = 1
MSR bit 6 DIO may incorrectly read as 1
```

For write execution, treat `RQM=1` and `EXM=1` as "feed one byte to the FDC
data register" even if `DIO=1`.

Do not read from the FDC data register while `EXM=1` just because `DIO=1`.
On the tested ULIfAC setup, attempting to read the data register in that state
froze the machine.

## Proven Fix

The working runtime write loop in `tools\runtime_overlay_loader.s`:

- issues `SPECIFY` before recalibrate/seek so the loader owns non-DMA timing;
- sends command `0x45` (`WRITE DATA`, MFM);
- disables interrupts for the data phase;
- waits for `RQM=1`;
- requires `EXM=1` before sending payload bytes;
- ignores `DIO` while `EXM=1`;
- outputs one byte to `0xFB7F`;
- repeats until `EXM` clears and result phase can be read;
- uses a bounded transfer guard so failure is non-fatal.

The high-score save path returns to the game on failure. It must not halt the
game, because persistence is optional and can depend on the storage device.

## Diagnostic Trail

The direct-FDC write diagnostics used `track 27`, sector `0xC1`, and write
signature `WR07`.

Observed results:

- `P 3A`: all nine `WRITE DATA` command bytes were accepted. The problem was
  not recalibrate, seek, or command-byte submission.
- No-data diagnostic reported:

```text
FAIL STEP 3E
MSR F0
ST EE EE EE EE EE EE EE EE
W 57 52 30 37
R EE EE EE EE
```

`MSR F0` means `RQM=1`, `DIO=1`, `EXM=1`, and controller busy. For a normal
write-data feed this looked like "read data available", but reading it was
wrong for ULIfAC.

- Result-read diagnostic stopped at `P D0`, confirming that reading the data
  register in the `MSR F0` write-execution state can freeze.
- The working build ignored `DIO` during write execution and fed data whenever
  `RQM=1` and `EXM=1`.

## Reusable Diagnostic Tools

- `tools\fdc_write_diagnostic_loader.s`
- `tools\build_fdc_write_diagnostic_dsk.ps1`

Build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_fdc_write_diagnostic_dsk.ps1
```

Run:

```basic
RUN"FDWTEST.BIN"
```

The diagnostic prints phase markers:

```text
P 31  WRITE DATA command byte
P 32  drive/head
P 33  track
P 34  head
P 35  sector
P 36  size
P 37  EOT
P 38  GPL
P 39  DTL
P 3A  data-transfer phase
```

Keep this tool for future direct-FDC games. It gives a small, isolated way to
test write behavior without changing the game.

## Future Guidance

- Keep direct-FDC reads and writes separate in diagnostics. Reads can work even
  when writes fail.
- Record the last phase marker and `MSR` value before changing the loader.
- On ULIfAC, do not assume `DIO` is reliable during write execution.
- Use a write guard. If the controller never leaves execution phase, return
  failure rather than freezing.
- Do not perform hidden-sector loads or saves while ULIfAC WiFi mode is active
  unless storage/WiFi mode switching has been proven.
