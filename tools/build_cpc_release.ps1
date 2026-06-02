$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$LocalBash = Join-Path $Root.Path "toolchains\cygwin64\bin\bash.exe"
$SharedCpct = Join-Path $Root.Path "..\cpctelera"
$LegacyLocalCpct = Join-Path $Root.Path ".cpctelera-ref\cpctelera"

function Convert-ToCygwinPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = Resolve-Path $Path
    $unixPath = $resolved.Path.Replace("\", "/")
    if ($unixPath -match "^([A-Za-z]):/(.*)$") {
        return "/cygdrive/$($matches[1].ToLower())/$($matches[2])"
    }
    return $unixPath
}

function Read-HexAddressFromLog {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    foreach ($line in Get-Content $Path) {
        if ($line -match "$Label\s*=\s*([0-9A-Fa-f]+)") {
            return [Convert]::ToInt32($matches[1], 16)
        }
    }
    throw "Could not find '$Label' in $Path."
}

function Get-CpctPath {
    if ($env:CPCT_PATH -and (Test-Path $env:CPCT_PATH)) {
        return (Resolve-Path $env:CPCT_PATH).Path
    }

    if (Test-Path $SharedCpct) {
        return (Resolve-Path $SharedCpct).Path
    }

    if (Test-Path $LegacyLocalCpct) {
        return (Resolve-Path $LegacyLocalCpct).Path
    }

    return $null
}

function Set-WordLE {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][int]$Offset,
        [Parameter(Mandatory = $true)][int]$Value
    )

    $Bytes[$Offset] = [byte]($Value -band 0xFF)
    $Bytes[$Offset + 1] = [byte](($Value -shr 8) -band 0xFF)
}

function Write-AmsdosBinary {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][int]$LoadAddress,
        [Parameter(Mandatory = $true)][int]$RunAddress,
        [Parameter(Mandatory = $true)][string]$AmsdosName
    )

    $payload = [System.IO.File]::ReadAllBytes((Resolve-Path $InputPath))
    $header = New-Object byte[] 128
    $nameBytes = New-Object byte[] 11
    for ($i = 0; $i -lt $nameBytes.Length; $i++) {
        $nameBytes[$i] = [byte][char]' '
    }

    $parts = $AmsdosName.ToUpperInvariant().Split(".", 2)
    $base = $parts[0]
    $ext = if ($parts.Length -gt 1) { $parts[1] } else { "" }
    $baseBytes = [System.Text.Encoding]::ASCII.GetBytes($base.Substring(0, [Math]::Min(8, $base.Length)))
    $extBytes = [System.Text.Encoding]::ASCII.GetBytes($ext.Substring(0, [Math]::Min(3, $ext.Length)))
    [Array]::Copy($baseBytes, 0, $nameBytes, 0, $baseBytes.Length)
    [Array]::Copy($extBytes, 0, $nameBytes, 8, $extBytes.Length)
    [Array]::Copy($nameBytes, 0, $header, 1, 11)

    $header[0x12] = 2
    Set-WordLE $header 0x15 $LoadAddress
    Set-WordLE $header 0x18 $payload.Length
    Set-WordLE $header 0x1A $RunAddress
    Set-WordLE $header 0x40 ($payload.Length -band 0xFFFF)
    $header[0x42] = [byte](($payload.Length -shr 16) -band 0xFF)

    $checksum = 0
    for ($i = 0; $i -lt 67; $i++) {
        $checksum += $header[$i]
    }
    Set-WordLE $header 0x43 ($checksum -band 0xFFFF)

    $output = New-Object byte[] ($header.Length + $payload.Length)
    [Array]::Copy($header, 0, $output, 0, $header.Length)
    [Array]::Copy($payload, 0, $output, $header.Length, $payload.Length)
    [System.IO.File]::WriteAllBytes($OutputPath, $output)
}

Push-Location $Root
try {
    $CpctPath = Get-CpctPath
    if ((Test-Path $LocalBash) -and $CpctPath) {
        $cygRoot = Convert-ToCygwinPath $Root.Path
        $cygCpct = Convert-ToCygwinPath $CpctPath
        $cmd = "cd '$cygRoot' && export CPCT_PATH='$cygCpct' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/iDSK-0.13/bin:$cygCpct/tools/hex2bin-2.0/bin:$cygCpct/tools/2cdt/bin:$cygCpct/tools/dskgen/bin':`$PATH && make"
        & $LocalBash -lc $cmd
        if ($LASTEXITCODE -ne 0) {
            throw "CPCtelera make failed with exit code $LASTEXITCODE."
        }
    } else {
        $make = Get-Command make -ErrorAction SilentlyContinue
        if (-not $make) {
            throw "CPCtelera native build requires Cygwin, make, and CPCT_PATH. Local toolchain not found under $($Root.Path)\toolchains and no shared CPCtelera path was found."
        }
        make
    }

    New-Item -ItemType Directory -Force -Path "dist" | Out-Null
    Remove-Item -Force -ErrorAction SilentlyContinue "dist\TETRIS.map"
    $loadAddress = Read-HexAddressFromLog "obj\binaryAddresses.log" "Load Address"
    $runAddress = Read-HexAddressFromLog "obj\binaryAddresses.log" "Run\s+Address"
    $highestAddress = Read-HexAddressFromLog "obj\TETRIS.bin.log" "Highest address"
    $safeAmsdosTop = 0xA67B
    if ($highestAddress -ge $safeAmsdosTop) {
        throw ("Built binary reaches 0x{0:X4}, which can overwrite CPC AMSDOS/BASIC high memory. Keep it below 0x{1:X4} for direct RUN compatibility." -f $highestAddress, $safeAmsdosTop)
    }
    Write-AmsdosBinary "obj\TETRIS.bin" "dist\TETRIS.BIN" $loadAddress $runAddress "TETRIS.BIN"
    Copy-Item -Force "TETRIS.cdt" "dist\TETRIS.CDT"
    try {
        Copy-Item -Force "TETRIS.dsk" "dist\TETRIS.DSK"
    } catch {
        $fallbackDsk = "dist\TETRIS-UPDATED.DSK"
        Copy-Item -Force "TETRIS.dsk" $fallbackDsk
        Write-Warning "Could not overwrite dist\TETRIS.DSK, probably because an emulator has it open. Wrote $fallbackDsk instead."
    }
} finally {
    Pop-Location
}
