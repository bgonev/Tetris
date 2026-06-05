param(
    [string]$OutputDsk = "dist\FDC-DIAG-TRACK35.DSK",
    [int]$LoaderLoadAddress = 0x0800,
    [int]$TestTrack = 35
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$LocalBash = Join-Path $Root.Path "toolchains\cygwin64\bin\bash.exe"
$SharedCpct = Join-Path $Root.Path "..\cpctelera"
$SectorSize = 512
$SectorIds = @(0xC1, 0xC6, 0xC2, 0xC7, 0xC3, 0xC8, 0xC4, 0xC9, 0xC5)

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

function Get-CpctPath {
    if ($env:CPCT_PATH -and (Test-Path $env:CPCT_PATH)) {
        return (Resolve-Path $env:CPCT_PATH).Path
    }
    if (Test-Path $SharedCpct) {
        return (Resolve-Path $SharedCpct).Path
    }
    return $null
}

function Write-TestSector {
    param(
        [Parameter(Mandatory = $true)][string]$DskPath,
        [Parameter(Mandatory = $true)][int]$Track
    )

    $dsk = [System.IO.File]::ReadAllBytes((Resolve-Path $DskPath))
    $trackSize = [int]$dsk[0x32] + ([int]$dsk[0x33] -shl 8)
    if ($trackSize -eq 0) {
        throw "Unsupported DSK header: fixed track size is zero."
    }

    $trackOffset = 0x100 + ($Track * $trackSize)
    if ($trackOffset + 0x100 -gt $dsk.Length) {
        throw "Track $Track is outside this DSK image."
    }

    $sectorId = [int]$SectorIds[0]
    $sectorCountOnTrack = [int]$dsk[$trackOffset + 0x15]
    $dataOffset = $trackOffset + 0x100
    $found = $false

    for ($s = 0; $s -lt $sectorCountOnTrack; $s++) {
        $entryOffset = $trackOffset + 0x18 + ($s * 8)
        $n = [int]$dsk[$entryOffset + 3]
        $size = [int]$dsk[$entryOffset + 6] + ([int]$dsk[$entryOffset + 7] -shl 8)
        if ($size -eq 0) {
            $size = 128 -shl $n
        }

        if ([int]$dsk[$entryOffset + 2] -eq $sectorId) {
            for ($j = 0; $j -lt $SectorSize; $j++) {
                $dsk[$dataOffset + $j] = 0
            }
            $dsk[$dataOffset + 0] = 0x46
            $dsk[$dataOffset + 1] = 0x4E
            $dsk[$dataOffset + 2] = 0x54
            $dsk[$dataOffset + 3] = 0x35
            [System.IO.File]::WriteAllBytes((Resolve-Path $DskPath), $dsk)
            $found = $true
            break
        }

        $dataOffset += $size
    }

    if (-not $found) {
        throw ("Could not find sector 0x{0:X2} on track {1}." -f $sectorId, $Track)
    }
}

function Test-TestSector {
    param(
        [Parameter(Mandatory = $true)][string]$DskPath,
        [Parameter(Mandatory = $true)][int]$Track
    )

    $dsk = [System.IO.File]::ReadAllBytes((Resolve-Path $DskPath))
    $trackSize = [int]$dsk[0x32] + ([int]$dsk[0x33] -shl 8)
    $trackOffset = 0x100 + ($Track * $trackSize)
    $sectorId = [int]$SectorIds[0]
    $sectorCountOnTrack = [int]$dsk[$trackOffset + 0x15]
    $dataOffset = $trackOffset + 0x100

    for ($s = 0; $s -lt $sectorCountOnTrack; $s++) {
        $entryOffset = $trackOffset + 0x18 + ($s * 8)
        $n = [int]$dsk[$entryOffset + 3]
        $size = [int]$dsk[$entryOffset + 6] + ([int]$dsk[$entryOffset + 7] -shl 8)
        if ($size -eq 0) {
            $size = 128 -shl $n
        }

        if ([int]$dsk[$entryOffset + 2] -eq $sectorId) {
            if ($dsk[$dataOffset] -ne 0x46 -or $dsk[$dataOffset + 1] -ne 0x4E -or $dsk[$dataOffset + 2] -ne 0x54 -or $dsk[$dataOffset + 3] -ne 0x35) {
                throw "Track $Track sector 0xC1 does not contain FNT5."
            }
            return
        }

        $dataOffset += $size
    }

    throw ("Could not verify sector 0x{0:X2} on track {1}." -f $sectorId, $Track)
}

Push-Location $Root
try {
    $cpctPath = Get-CpctPath
    if (-not $cpctPath) {
        throw "Could not find CPCtelera at $SharedCpct or CPCT_PATH."
    }
    if (-not (Test-Path $LocalBash)) {
        throw "Could not find local Cygwin bash at $LocalBash."
    }

    New-Item -ItemType Directory -Force -Path "obj\fdcdiag" | Out-Null
    New-Item -ItemType Directory -Force -Path "dist" | Out-Null

    $cygRoot = Convert-ToCygwinPath $Root.Path
    $cygCpct = Convert-ToCygwinPath $cpctPath
    $cygOutputDsk = Convert-ToCygwinPath $OutputDsk

    $asmCmd = "cd '$cygRoot' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/hex2bin-2.0/bin':`$PATH && sdasz80 -l -o -s obj/fdcdiag/fdc_diagnostic_loader.rel tools/fdc_diagnostic_loader.s && sdcc -mz80 --no-std-crt0 --code-loc $('0x{0:X4}' -f $LoaderLoadAddress) --data-loc 0 obj/fdcdiag/fdc_diagnostic_loader.rel -o obj/fdcdiag/fdc_diagnostic_loader.ihx && hex2bin -p 00 obj/fdcdiag/fdc_diagnostic_loader.ihx"
    & $LocalBash -lc $asmCmd
    if ($LASTEXITCODE -ne 0) {
        throw "FDC diagnostic loader build failed with exit code $LASTEXITCODE."
    }

    Copy-Item -Force "obj\fdcdiag\fdc_diagnostic_loader.bin" "obj\fdcdiag\FDCTEST.BIN"
    Remove-Item -Force -ErrorAction SilentlyContinue $OutputDsk

    $idskCmd = "cd '$cygRoot' && export PATH='$cygCpct/tools/iDSK-0.13/bin':`$PATH && iDSK '$cygOutputDsk' -n && iDSK '$cygOutputDsk' -i obj/fdcdiag/FDCTEST.BIN -e $('{0:X4}' -f $LoaderLoadAddress) -c $('{0:X4}' -f $LoaderLoadAddress) -t 1 -f"
    & $LocalBash -lc $idskCmd
    if ($LASTEXITCODE -ne 0) {
        throw "FDC diagnostic DSK creation failed with exit code $LASTEXITCODE."
    }

    Write-TestSector $OutputDsk $TestTrack
    Test-TestSector $OutputDsk $TestTrack

    Write-Host ("FDC diagnostic DSK: {0}" -f (Resolve-Path $OutputDsk))
    Write-Host ("Loader: load/run 0x{0:X4}; size {1} bytes" -f $LoaderLoadAddress, (Get-Item "obj\fdcdiag\fdc_diagnostic_loader.bin").Length)
    Write-Host ("Hidden test sector: track {0}; sector 0xC1; signature FNT5 at offset 0" -f $TestTrack)
} finally {
    Pop-Location
}
