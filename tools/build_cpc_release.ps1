$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$LocalBash = Join-Path $Root.Path "toolchains\cygwin64\bin\bash.exe"
$SharedCpct = Join-Path $Root.Path "..\cpctelera"
$LegacyLocalCpct = Join-Path $Root.Path ".cpctelera-ref\cpctelera"
$PayloadFileName = "GAME.DAT"
$LegacyDist = "dist\nonoverlay"

function Convert-ToCygwinPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = if (Test-Path $Path) {
        (Resolve-Path $Path).Path
    } else {
        [System.IO.Path]::GetFullPath($Path)
    }
    $unixPath = $fullPath.Replace("\", "/")
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

function Format-CpcHex {
    param([Parameter(Mandatory = $true)][int]$Value)

    return ("&{0:X4}" -f $Value)
}

function Write-BasicLoader {
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][int]$MemoryTop,
        [Parameter(Mandatory = $true)][int]$LoadAddress,
        [Parameter(Mandatory = $true)][int]$RunAddress
    )

    $lines = @(
        '10 OPENOUT "D"',
        ("20 MEMORY {0}" -f (Format-CpcHex $MemoryTop)),
        '30 CLOSEOUT',
        ('40 LOAD "{0}",{1}' -f $PayloadFileName, (Format-CpcHex $LoadAddress)),
        ("50 CALL {0}" -f (Format-CpcHex $RunAddress))
    )
    $text = ($lines -join "`r`n") + "`r`n" + [char]0x1A
    [System.IO.File]::WriteAllBytes($OutputPath, [System.Text.Encoding]::ASCII.GetBytes($text))
}

function Add-AsciiFileToDsk {
    param(
        [Parameter(Mandatory = $true)][string]$DskPath,
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$CpctPath
    )

    if (Test-Path $LocalBash) {
        $cygCpct = Convert-ToCygwinPath $CpctPath
        $cygDsk = Convert-ToCygwinPath $DskPath
        $cygInput = Convert-ToCygwinPath $InputPath
        $cmd = "export PATH='$cygCpct/tools/iDSK-0.13/bin':`$PATH && iDSK '$cygDsk' -i '$cygInput' -t 0 -f"
        & $LocalBash -lc $cmd
    } else {
        $idsk = Join-Path $CpctPath "tools\iDSK-0.13\bin\iDSK.exe"
        if (-not (Test-Path $idsk)) {
            throw "Could not find iDSK at $idsk."
        }
        & $idsk $DskPath -i $InputPath -t 0 -f
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Could not add BASIC loader to $DskPath."
    }
}

function New-NoBasicDsk {
    param(
        [Parameter(Mandatory = $true)][string]$DskPath,
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [Parameter(Mandatory = $true)][string]$PayloadPath,
        [Parameter(Mandatory = $true)][int]$PayloadLoadAddress,
        [Parameter(Mandatory = $true)][int]$PayloadRunAddress,
        [Parameter(Mandatory = $true)][string]$CpctPath
    )

    $load = "{0:X4}" -f $PayloadLoadAddress
    $run = "{0:X4}" -f $PayloadRunAddress

    Remove-Item -Force -ErrorAction SilentlyContinue $DskPath

    if (Test-Path $LocalBash) {
        $cygCpct = Convert-ToCygwinPath $CpctPath
        $cygDsk = Convert-ToCygwinPath $DskPath
        $cygLauncher = Convert-ToCygwinPath $LauncherPath
        $cygPayload = Convert-ToCygwinPath $PayloadPath
        $cmd = "export PATH='$cygCpct/tools/iDSK-0.13/bin':`$PATH && iDSK '$cygDsk' -n && iDSK '$cygDsk' -i '$cygLauncher' -t 0 -f && iDSK '$cygDsk' -i '$cygPayload' -e $run -c $load -t 1 -f"
        & $LocalBash -lc $cmd
    } else {
        $idsk = Join-Path $CpctPath "tools\iDSK-0.13\bin\iDSK.exe"
        if (-not (Test-Path $idsk)) {
            throw "Could not find iDSK at $idsk."
        }

        & $idsk $DskPath -n
        if ($LASTEXITCODE -ne 0) { throw "Release DSK creation failed with exit code $LASTEXITCODE." }
        & $idsk $DskPath -i $LauncherPath -t 0 -f
        if ($LASTEXITCODE -ne 0) { throw "Could not add TETRIS.BIN launcher to release DSK." }
        & $idsk $DskPath -i $PayloadPath -e $run -c $load -t 1 -f
        if ($LASTEXITCODE -ne 0) { throw "Could not add $PayloadFileName payload to release DSK." }
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Could not create no-BASIC release DSK."
    }
}

function New-NoBasicCdt {
    param(
        [Parameter(Mandatory = $true)][string]$CdtPath,
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [Parameter(Mandatory = $true)][string]$PayloadRawPath,
        [Parameter(Mandatory = $true)][int]$PayloadLoadAddress,
        [Parameter(Mandatory = $true)][int]$PayloadRunAddress,
        [Parameter(Mandatory = $true)][string]$CpctPath
    )

    $load = "0x{0:X4}" -f $PayloadLoadAddress
    $run = "0x{0:X4}" -f $PayloadRunAddress

    Remove-Item -Force -ErrorAction SilentlyContinue $CdtPath

    if (Test-Path $LocalBash) {
        $cygCpct = Convert-ToCygwinPath $CpctPath
        $cygCdt = Convert-ToCygwinPath $CdtPath
        $cygLauncher = Convert-ToCygwinPath $LauncherPath
        $cygPayload = Convert-ToCygwinPath $PayloadRawPath
        $cmd = "export PATH='$cygCpct/tools/2cdt/bin':`$PATH && 2cdt -n . '$cygCdt' > /dev/null && 2cdt -F 0 '$cygLauncher' -r TETRIS.BIN '$cygCdt' > /dev/null && 2cdt -X $run -L $load -r $PayloadFileName '$cygPayload' '$cygCdt' > /dev/null"
        & $LocalBash -lc $cmd
    } else {
        $twocdt = Join-Path $CpctPath "tools\2cdt\bin\2cdt.exe"
        if (-not (Test-Path $twocdt)) {
            throw "Could not find 2cdt at $twocdt."
        }

        & $twocdt -n . $CdtPath
        if ($LASTEXITCODE -ne 0) { throw "Release CDT creation failed with exit code $LASTEXITCODE." }
        & $twocdt -F 0 $LauncherPath -r TETRIS.BIN $CdtPath
        if ($LASTEXITCODE -ne 0) { throw "Could not add TETRIS.BIN launcher to release CDT." }
        & $twocdt -X $run -L $load -r $PayloadFileName $PayloadRawPath $CdtPath
        if ($LASTEXITCODE -ne 0) { throw "Could not add $PayloadFileName payload to release CDT." }
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Could not create no-BASIC release CDT."
    }
}

Push-Location $Root
try {
    $CpctPath = Get-CpctPath
    if ((Test-Path $LocalBash) -and $CpctPath) {
        $cygRoot = Convert-ToCygwinPath $Root.Path
        $cygCpct = Convert-ToCygwinPath $CpctPath
        $cmd = "cd '$cygRoot' && export CPCT_PATH='$cygCpct' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/iDSK-0.13/bin:$cygCpct/tools/hex2bin-2.0/bin:$cygCpct/tools/2cdt/bin:$cygCpct/tools/dskgen/bin':`$PATH && make clean && make"
        & $LocalBash -lc $cmd
        if ($LASTEXITCODE -ne 0) {
            throw "CPCtelera make failed with exit code $LASTEXITCODE."
        }
    } else {
        $make = Get-Command make -ErrorAction SilentlyContinue
        if (-not $make) {
            throw "CPCtelera native build requires Cygwin, make, and CPCT_PATH. Local toolchain not found under $($Root.Path)\toolchains and no shared CPCtelera path was found."
        }
        make clean
        if ($LASTEXITCODE -ne 0) {
            throw "CPCtelera make clean failed with exit code $LASTEXITCODE."
        }
        make
        if ($LASTEXITCODE -ne 0) {
            throw "CPCtelera make failed with exit code $LASTEXITCODE."
        }
    }

    New-Item -ItemType Directory -Force -Path $LegacyDist | Out-Null
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $LegacyDist "TETRIS.map")
    Remove-Item -Force -ErrorAction SilentlyContinue "obj\TETRIS.BAS", (Join-Path $LegacyDist "TETRIS.BAS")
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $LegacyDist "GAME.BIN"), (Join-Path $LegacyDist "GAME.DAT")

    $loadAddress = Read-HexAddressFromLog "obj\binaryAddresses.log" "Load Address"
    $runAddress = Read-HexAddressFromLog "obj\binaryAddresses.log" "Run\s+Address"
    $highestAddress = Read-HexAddressFromLog "obj\TETRIS.bin.log" "Highest address"
    $loaderMemoryTop = $loadAddress - 1
    $safeAmsdosTop = 0xA67B
    if ($highestAddress -ge $safeAmsdosTop) {
        throw ("Built binary reaches 0x{0:X4}, which can overwrite CPC AMSDOS/BASIC high memory. Keep it below 0x{1:X4} for loader compatibility." -f $highestAddress, $safeAmsdosTop)
    }

    New-Item -ItemType Directory -Force -Path "obj\launcher" | Out-Null
    New-Item -ItemType Directory -Force -Path "obj\release" | Out-Null
    Write-BasicLoader "obj\launcher\TETRIS.BIN" $loaderMemoryTop $loadAddress $runAddress
    Copy-Item -Force "obj\TETRIS.bin" "obj\release\$PayloadFileName"
    Write-AmsdosBinary "obj\TETRIS.bin" (Join-Path $LegacyDist $PayloadFileName) $loadAddress $runAddress $PayloadFileName
    Copy-Item -Force "obj\launcher\TETRIS.BIN" (Join-Path $LegacyDist "TETRIS.BIN")
    New-NoBasicDsk "TETRIS.dsk" "obj\launcher\TETRIS.BIN" "obj\release\$PayloadFileName" $loadAddress $runAddress $CpctPath
    New-NoBasicCdt "TETRIS.cdt" "obj\launcher\TETRIS.BIN" "obj\TETRIS.bin" $loadAddress $runAddress $CpctPath
    Copy-Item -Force "TETRIS.cdt" (Join-Path $LegacyDist "TETRIS.CDT")
    $releaseDskPath = Join-Path $LegacyDist "TETRIS.DSK"
    try {
        Copy-Item -Force "TETRIS.dsk" $releaseDskPath
    } catch {
        $fallbackDsk = Join-Path $LegacyDist "TETRIS-UPDATED.DSK"
        Copy-Item -Force "TETRIS.dsk" $fallbackDsk
        $releaseDskPath = $fallbackDsk
        Write-Warning "Could not overwrite $releaseDskPath, probably because an emulator has it open. Wrote $fallbackDsk instead."
    }
    Copy-Item -Force (Join-Path $LegacyDist "TETRIS.BIN") (Join-Path $LegacyDist "TETRIS-nonoverlay.BIN")
    Copy-Item -Force (Join-Path $LegacyDist $PayloadFileName) (Join-Path $LegacyDist "GAME-nonoverlay.DAT")
    Copy-Item -Force (Join-Path $LegacyDist "TETRIS.CDT") (Join-Path $LegacyDist "TETRIS-nonoverlay.CDT")
    Copy-Item -Force $releaseDskPath (Join-Path $LegacyDist "TETRIS-nonoverlay.DSK")
    Write-Host ("Launcher MEMORY top: 0x{0:X4}; payload: {1}; code load: 0x{2:X4}; run: 0x{3:X4}; highest: 0x{4:X4}; safe top: 0x{5:X4}" -f $loaderMemoryTop, $PayloadFileName, $loadAddress, $runAddress, $highestAddress, $safeAmsdosTop)
    Write-Host ("Non-overlay outputs: {0}" -f (Resolve-Path $LegacyDist))
} finally {
    Pop-Location
}
