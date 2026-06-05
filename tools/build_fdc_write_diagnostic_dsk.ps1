param(
    [string]$OutputDsk = "dist\FDC-WRITE-DIAG-TRACK27.DSK",
    [int]$LoaderLoadAddress = 0x0800
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$LocalBash = Join-Path $Root.Path "toolchains\cygwin64\bin\bash.exe"
$SharedCpct = Join-Path $Root.Path "..\cpctelera"

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

Push-Location $Root
try {
    $cpctPath = Get-CpctPath
    if (-not $cpctPath) {
        throw "Could not find CPCtelera at $SharedCpct or CPCT_PATH."
    }
    if (-not (Test-Path $LocalBash)) {
        throw "Could not find local Cygwin bash at $LocalBash."
    }

    New-Item -ItemType Directory -Force -Path "obj\fdcwdiag" | Out-Null
    New-Item -ItemType Directory -Force -Path "dist" | Out-Null

    $cygRoot = Convert-ToCygwinPath $Root.Path
    $cygCpct = Convert-ToCygwinPath $cpctPath
    $cygOutputDsk = Convert-ToCygwinPath $OutputDsk

    $asmCmd = "cd '$cygRoot' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/hex2bin-2.0/bin':`$PATH && sdasz80 -l -o -s obj/fdcwdiag/fdc_write_diagnostic_loader.rel tools/fdc_write_diagnostic_loader.s && sdcc -mz80 --no-std-crt0 --code-loc $('0x{0:X4}' -f $LoaderLoadAddress) --data-loc 0 obj/fdcwdiag/fdc_write_diagnostic_loader.rel -o obj/fdcwdiag/fdc_write_diagnostic_loader.ihx && hex2bin -p 00 obj/fdcwdiag/fdc_write_diagnostic_loader.ihx"
    & $LocalBash -lc $asmCmd
    if ($LASTEXITCODE -ne 0) {
        throw "FDC write diagnostic loader build failed with exit code $LASTEXITCODE."
    }

    Copy-Item -Force "obj\fdcwdiag\fdc_write_diagnostic_loader.bin" "obj\fdcwdiag\FDWTEST.BIN"
    Remove-Item -Force -ErrorAction SilentlyContinue $OutputDsk

    $idskCmd = "cd '$cygRoot' && export PATH='$cygCpct/tools/iDSK-0.13/bin':`$PATH && iDSK '$cygOutputDsk' -n && iDSK '$cygOutputDsk' -i obj/fdcwdiag/FDWTEST.BIN -e $('{0:X4}' -f $LoaderLoadAddress) -c $('{0:X4}' -f $LoaderLoadAddress) -t 1 -f"
    & $LocalBash -lc $idskCmd
    if ($LASTEXITCODE -ne 0) {
        throw "FDC write diagnostic DSK creation failed with exit code $LASTEXITCODE."
    }

    Write-Host ("FDC write diagnostic DSK: {0}" -f (Resolve-Path $OutputDsk))
    Write-Host ("Loader: load/run 0x{0:X4}; size {1} bytes" -f $LoaderLoadAddress, (Get-Item "obj\fdcwdiag\fdc_write_diagnostic_loader.bin").Length)
    Write-Host "Test target: track 27; sector 0xC1; write signature WR07"
} finally {
    Pop-Location
}
