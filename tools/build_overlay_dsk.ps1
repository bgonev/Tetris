param(
    [string]$OutputDsk = "dist\TETRIS.DSK",
    [int]$LoaderLoadAddress = 0x0800,
    [int]$PayloadStartTrack = 20,
    [int]$SplashAddress = 0x5000,
    [int]$SplashStartTrack = 30,
    [int]$GameplayMusicAddress = 0x9400,
    [int]$MenuCodeAddress = 0x5400,
    [int]$MenuCodeSectorCount = 3,
    [switch]$DirectFdcBoot,
    [switch]$AmsdosBoot,
    [switch]$SkipGameBuild
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$LocalBash = Join-Path $Root.Path "toolchains\cygwin64\bin\bash.exe"
$SharedCpct = Join-Path $Root.Path "..\cpctelera"
$SectorIds = @(0xC1, 0xC6, 0xC2, 0xC7, 0xC3, 0xC8, 0xC4, 0xC9, 0xC5)
$SectorSize = 512
$ReleaseVersion = "v0.5"

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
    [System.IO.File]::WriteAllBytes(([System.IO.Path]::GetFullPath($OutputPath)), $output)
}

function Copy-IfDifferent {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    $sourceFull = [System.IO.Path]::GetFullPath($SourcePath)
    $destinationFull = [System.IO.Path]::GetFullPath($DestinationPath)
    if ($sourceFull -ne $destinationFull) {
        Copy-Item -Force $SourcePath $DestinationPath
    }
}

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

function Get-SplashImageLength {
    param([Parameter(Mandatory = $true)][string]$HeaderPath)

    $header = Get-Content -Raw $HeaderPath
    if ($header -notmatch "#define\s+SPLASH_W_BYTES\s+([0-9]+)") {
        throw "Could not find SPLASH_W_BYTES in $HeaderPath."
    }
    $widthBytes = [int]$matches[1]
    if ($header -notmatch "#define\s+SPLASH_HEIGHT\s+([0-9]+)") {
        throw "Could not find SPLASH_HEIGHT in $HeaderPath."
    }
    $height = [int]$matches[1]
    return $widthBytes * $height
}

function Get-AsmDataBlock {
    param(
        [Parameter(Mandatory = $true)][string]$MusicSource,
        [Parameter(Mandatory = $true)][string]$StartLabel,
        [Parameter(Mandatory = $true)][string]$EndPattern
    )

    $pattern = "(?ms)^$([regex]::Escape($StartLabel)):\s*`r?`n.*?(?=^$EndPattern)"
    $match = [regex]::Match($MusicSource, $pattern)
    if (-not $match.Success) {
        throw "Could not find $StartLabel block in src\music.s."
    }
    return $match.Value.TrimEnd()
}

function Get-AsmDataBlockSize {
    param([Parameter(Mandatory = $true)][string]$Block)

    $size = 0
    foreach ($line in ($Block -split "`r?`n")) {
        $clean = ($line -split ";", 2)[0].Trim()
        if ($clean -match "^\.dw\s+(.+)$") {
            $values = $matches[1].Split(",") | Where-Object { $_.Trim().Length -gt 0 }
            $size += 2 * $values.Count
        } elseif ($clean -match "^\.db\s+(.+)$") {
            $values = $matches[1].Split(",") | Where-Object { $_.Trim().Length -gt 0 }
            $size += $values.Count
        }
    }
    return $size
}

function New-OverlayMusicSources {
    param(
        [Parameter(Mandatory = $true)][string]$MusicSourcePath,
        [Parameter(Mandatory = $true)][string]$ResidentOutputPath,
        [Parameter(Mandatory = $true)][string]$TitleOverlayOutputPath,
        [Parameter(Mandatory = $true)][string]$GameplayOverlayOutputPath,
        [Parameter(Mandatory = $true)][int]$TitleMusicAddress,
        [Parameter(Mandatory = $true)][int]$GameplayMusicAddress
    )

    $musicSource = Get-Content -Raw $MusicSourcePath
    $gameplayBlock = Get-AsmDataBlock $musicSource "korobeiniki_data" "troika_data:"
    $titleBlock = Get-AsmDataBlock $musicSource "troika_data" "\.area\s+_CODE"
    $titleMusicLength = Get-AsmDataBlockSize $titleBlock
    $gameplayMusicLength = Get-AsmDataBlockSize $gameplayBlock

    $residentSource = $musicSource.Replace($gameplayBlock, "")
    $residentSource = $residentSource.Replace($titleBlock, "")
    $residentSource = $residentSource.Replace("ld de, #korobeiniki_data", ("ld de, #0x{0:X4}" -f $GameplayMusicAddress))
    $residentSource = $residentSource.Replace("ld de, #troika_data", ("ld de, #0x{0:X4}" -f $TitleMusicAddress))
    Set-Content -Path $ResidentOutputPath -Value $residentSource -Encoding ascii

    $titleOverlaySource = ".area _DATA`r`n`r`n.area _CODE`r`n`r`n" + $titleBlock + "`r`n"
    Set-Content -Path $TitleOverlayOutputPath -Value $titleOverlaySource -Encoding ascii

    $gameplayOverlaySource = ".area _DATA`r`n`r`n.area _CODE`r`n`r`n" + $gameplayBlock + "`r`n"
    Set-Content -Path $GameplayOverlayOutputPath -Value $gameplayOverlaySource -Encoding ascii

    return [PSCustomObject]@{
        TitleMusicAddress = $TitleMusicAddress
        TitleMusicLength = $titleMusicLength
        GameplayMusicAddress = $GameplayMusicAddress
        GameplayMusicLength = $gameplayMusicLength
    }
}

function Join-BinaryFiles {
    param(
        [Parameter(Mandatory = $true)][string]$FirstPath,
        [Parameter(Mandatory = $true)][string]$SecondPath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $first = [System.IO.File]::ReadAllBytes((Resolve-Path $FirstPath))
    $second = [System.IO.File]::ReadAllBytes((Resolve-Path $SecondPath))
    $output = New-Object byte[] ($first.Length + $second.Length)
    [Array]::Copy($first, 0, $output, 0, $first.Length)
    [Array]::Copy($second, 0, $output, $first.Length, $second.Length)
    [System.IO.File]::WriteAllBytes($OutputPath, $output)
}

function Set-AsmLabelValue {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Directive,
        [Parameter(Mandatory = $true)][int]$Value
    )

    $pattern = "($([regex]::Escape($Label)):\s*`r?`n\s*\.$Directive\s+)#(?:0x)?[0-9A-Fa-f]+"
    return [regex]::Replace($Source, $pattern, {
        param($match)
        $match.Groups[1].Value + ("#0x{0:X}" -f $Value)
    })
}

function Set-AsmEquValue {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Value
    )

    $pattern = "($([regex]::Escape($Name))\s*=\s*)#(?:0x)?[0-9A-Fa-f]+"
    return [regex]::Replace($Source, $pattern, {
        param($match)
        $match.Groups[1].Value + ("#0x{0:X}" -f $Value)
    })
}

function New-OverlayLoaderSource {
    param(
        [Parameter(Mandatory = $true)][string]$TemplatePath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][int]$PayloadLoadAddress,
        [Parameter(Mandatory = $true)][int]$PayloadRunAddress,
        [Parameter(Mandatory = $true)][int]$PayloadSectorCount,
        [Parameter(Mandatory = $true)][int]$PayloadTrack,
        [Parameter(Mandatory = $true)][int]$WorkspaceTop
    )

    $source = Get-Content -Raw $TemplatePath
    $source = Set-AsmLabelValue $source "game_dest" "dw" $PayloadLoadAddress
    $source = Set-AsmLabelValue $source "game_track" "db" $PayloadTrack
    $source = Set-AsmLabelValue $source "game_sectors_left" "db" $PayloadSectorCount
    $source = Set-AsmEquValue $source "LOWEST_USABLE" $PayloadLoadAddress
    $source = Set-AsmEquValue $source "HIGHEST_USABLE" $WorkspaceTop
    $source = Set-AsmEquValue $source "PAYLOAD_RUN" $PayloadRunAddress
    Set-Content -Path $OutputPath -Value $source -Encoding ascii
}

function New-RuntimeOverlayLoaderSource {
    param(
        [Parameter(Mandatory = $true)][string]$TemplatePath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][int]$SplashTitleAddress,
        [Parameter(Mandatory = $true)][int]$SplashTitleTrack,
        [Parameter(Mandatory = $true)][int]$SplashTitleSectorCount,
        [Parameter(Mandatory = $true)][int]$GameplayAddress,
        [Parameter(Mandatory = $true)][int]$GameplayTrack,
        [Parameter(Mandatory = $true)][int]$GameplaySectorCount,
        [Parameter(Mandatory = $true)][int]$RuntimeFontAddress,
        [Parameter(Mandatory = $true)][int]$RuntimeFontTrack,
        [Parameter(Mandatory = $true)][int]$RuntimeFontSectorCount,
        [Parameter(Mandatory = $true)][int]$MenuCodeAddress,
        [Parameter(Mandatory = $true)][int]$MenuCodeTrack,
        [Parameter(Mandatory = $true)][int]$MenuCodeSectorCount
    )

    $source = Get-Content -Raw $TemplatePath
    $source = Set-AsmEquValue $source "SPLASH_TITLE_DEST" $SplashTitleAddress
    $source = Set-AsmEquValue $source "SPLASH_TITLE_TRACK" $SplashTitleTrack
    $source = Set-AsmEquValue $source "SPLASH_TITLE_SECTORS" $SplashTitleSectorCount
    $source = Set-AsmEquValue $source "GAMEPLAY_MUSIC_DEST" $GameplayAddress
    $source = Set-AsmEquValue $source "GAMEPLAY_MUSIC_TRACK" $GameplayTrack
    $source = Set-AsmEquValue $source "GAMEPLAY_MUSIC_SECTORS" $GameplaySectorCount
    $source = Set-AsmEquValue $source "RUNTIME_FONT_DEST" $RuntimeFontAddress
    $source = Set-AsmEquValue $source "RUNTIME_FONT_TRACK" $RuntimeFontTrack
    $source = Set-AsmEquValue $source "RUNTIME_FONT_SECTORS" $RuntimeFontSectorCount
    $source = Set-AsmEquValue $source "MENU_CODE_DEST" $MenuCodeAddress
    $source = Set-AsmEquValue $source "MENU_CODE_TRACK" $MenuCodeTrack
    $source = Set-AsmEquValue $source "MENU_CODE_SECTORS" $MenuCodeSectorCount
    Set-Content -Path $OutputPath -Value $source -Encoding ascii
}

function Get-FontGlyphBytes {
    param([Parameter(Mandatory = $true)][string]$SourcePath)

    $source = Get-Content -Raw $SourcePath
    $match = [regex]::Match($source, "(?ms)static\s+const\s+u8\s+fontGlyphs\s*\[[^\]]+\]\s*\[[^\]]+\]\s*=\s*\{(?<body>.*?)^\};")
    if (-not $match.Success) {
        throw "Could not find fontGlyphs table in $SourcePath."
    }

    $values = [regex]::Matches($match.Groups["body"].Value, "0x[0-9A-Fa-f]+|\b\d+\b")
    if ($values.Count -ne 273) {
        throw "Expected 273 font glyph bytes, found $($values.Count)."
    }

    $bytes = New-Object byte[] $values.Count
    for ($i = 0; $i -lt $values.Count; $i++) {
        $text = $values[$i].Value
        if ($text.StartsWith("0x")) {
            $bytes[$i] = [Convert]::ToByte($text.Substring(2), 16)
        } else {
            $bytes[$i] = [Convert]::ToByte($text, 10)
        }
    }
    return $bytes
}

function Get-CStaticInitializer {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $source = Get-Content -Raw $SourcePath
    $pattern = "(?ms)static\s+const\s+\w+\s+$([regex]::Escape($Name))\s*(?:\[[^\]]+\])+\s*=\s*\{(?<body>.*?)\};"
    $match = [regex]::Match($source, $pattern)
    if (-not $match.Success) {
        throw "Could not find $Name table in $SourcePath."
    }
    return $match.Groups["body"].Value
}

function Get-U8TableBytes {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$ExpectedCount
    )

    $body = Get-CStaticInitializer $SourcePath $Name
    $values = [regex]::Matches($body, "0x[0-9A-Fa-f]+|\b\d+\b")
    if ($values.Count -ne $ExpectedCount) {
        throw "Expected $ExpectedCount bytes in $Name, found $($values.Count)."
    }

    $bytes = New-Object byte[] $values.Count
    for ($i = 0; $i -lt $values.Count; $i++) {
        $text = $values[$i].Value
        $value = if ($text.StartsWith("0x")) {
            [Convert]::ToInt32($text.Substring(2), 16)
        } else {
            [Convert]::ToInt32($text, 10)
        }
        if ($value -lt 0 -or $value -gt 255) {
            throw "$Name value $value does not fit in one byte."
        }
        $bytes[$i] = [byte]$value
    }
    return $bytes
}

function Get-U16TableBytes {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$ExpectedCount
    )

    $body = Get-CStaticInitializer $SourcePath $Name
    $values = [regex]::Matches($body, "0x[0-9A-Fa-f]+|\b\d+\b")
    if ($values.Count -ne $ExpectedCount) {
        throw "Expected $ExpectedCount words in $Name, found $($values.Count)."
    }

    $bytes = New-Object byte[] ($values.Count * 2)
    for ($i = 0; $i -lt $values.Count; $i++) {
        $text = $values[$i].Value
        $value = if ($text.StartsWith("0x")) {
            [Convert]::ToInt32($text.Substring(2), 16)
        } else {
            [Convert]::ToInt32($text, 10)
        }
        if ($value -lt 0 -or $value -gt 65535) {
            throw "$Name value $value does not fit in one word."
        }
        $bytes[$i * 2] = [byte]($value -band 0xFF)
        $bytes[$i * 2 + 1] = [byte](($value -shr 8) -band 0xFF)
    }
    return $bytes
}

function Get-ShapeTableBytes {
    param([Parameter(Mandatory = $true)][string]$SourcePath)

    $body = Get-CStaticInitializer $SourcePath "shapes"
    $cells = [regex]::Matches($body, "SH\(\s*(\d+)\s*,\s*(\d+)\s*\)")
    if ($cells.Count -ne 112) {
        throw "Expected 112 tetromino shape cells, found $($cells.Count)."
    }

    $bytes = New-Object byte[] $cells.Count
    for ($i = 0; $i -lt $cells.Count; $i++) {
        $x = [Convert]::ToInt32($cells[$i].Groups[1].Value, 10)
        $y = [Convert]::ToInt32($cells[$i].Groups[2].Value, 10)
        if ($x -lt 0 -or $x -gt 15 -or $y -lt 0 -or $y -gt 15) {
            throw "Shape cell SH($x,$y) is outside the packed nibble range."
        }
        $bytes[$i] = [byte](($y -shl 4) -bor $x)
    }
    return $bytes
}

function Add-PayloadBytes {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[byte]]$PayloadBytes,
        [Parameter(Mandatory = $true)][byte[]]$Bytes
    )

    foreach ($byte in $Bytes) {
        $PayloadBytes.Add($byte)
    }
}

function Add-PayloadWord {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[byte]]$PayloadBytes,
        [Parameter(Mandatory = $true)][int]$Value
    )

    if ($Value -lt 0 -or $Value -gt 65535) {
        throw "Word value $Value is outside the 16-bit range."
    }

    $PayloadBytes.Add([byte]($Value -band 0xFF))
    $PayloadBytes.Add([byte](($Value -shr 8) -band 0xFF))
}

function Get-OverlayTextEntries {
    return @(
        [PSCustomObject]@{ Name = "TXT_MENU_TITLE"; Text = "Z32X TETRIS V.0.4" },
        [PSCustomObject]@{ Name = "TXT_GAME_OVER"; Text = "GAME OVER" },
        [PSCustomObject]@{ Name = "TXT_BLANK8"; Text = "        " },
        [PSCustomObject]@{ Name = "TXT_BLANK16"; Text = "                " },
        [PSCustomObject]@{ Name = "TXT_SCORE"; Text = "SCORE" },
        [PSCustomObject]@{ Name = "TXT_LEVEL"; Text = "LEVEL" },
        [PSCustomObject]@{ Name = "TXT_LINES"; Text = "LINES" },
        [PSCustomObject]@{ Name = "TXT_TETRIS"; Text = "TETRIS" },
        [PSCustomObject]@{ Name = "TXT_NEXT"; Text = "NEXT" },
        [PSCustomObject]@{ Name = "TXT_DEDICATION"; Text = "for my daughter Marija" },
        [PSCustomObject]@{ Name = "TXT_SET_PAD"; Text = "SET             " },
        [PSCustomObject]@{ Name = "TXT_REDEFINE_KEYS"; Text = "REDEFINE KEYS" },
        [PSCustomObject]@{ Name = "TXT_REDEFINE_KEYS_HINT"; Text = "USE O P Q A Z X M N" },
        [PSCustomObject]@{ Name = "TXT_SPACE_OR_CURSORS"; Text = "SPACE OR CURSORS" },
        [PSCustomObject]@{ Name = "TXT_SELECT"; Text = "SELECT" },
        [PSCustomObject]@{ Name = "TXT_MENU_KEYBOARD"; Text = "1 KEYBOARD" },
        [PSCustomObject]@{ Name = "TXT_MENU_JOYSTICK"; Text = "2 JOYSTICK" },
        [PSCustomObject]@{ Name = "TXT_MENU_REDEFINE"; Text = "3 REDEFINE" },
        [PSCustomObject]@{ Name = "TXT_KEYS"; Text = "KEYS" },
        [PSCustomObject]@{ Name = "TXT_LEFT"; Text = "LEFT" },
        [PSCustomObject]@{ Name = "TXT_RIGHT"; Text = "RIGHT" },
        [PSCustomObject]@{ Name = "TXT_ROTATE"; Text = "ROTATE" },
        [PSCustomObject]@{ Name = "TXT_DOWN"; Text = "DOWN" },
        [PSCustomObject]@{ Name = "TXT_DROP"; Text = "DROP" },
        [PSCustomObject]@{ Name = "TXT_PRESS_ANY_KEY"; Text = "PRESS ANY KEY" },
        [PSCustomObject]@{ Name = "TXT_KEY_UNKNOWN"; Text = "KEY" },
        [PSCustomObject]@{ Name = "TXT_KEY_O"; Text = "O" },
        [PSCustomObject]@{ Name = "TXT_KEY_P"; Text = "P" },
        [PSCustomObject]@{ Name = "TXT_KEY_Q"; Text = "Q" },
        [PSCustomObject]@{ Name = "TXT_KEY_A"; Text = "A" },
        [PSCustomObject]@{ Name = "TXT_KEY_Z"; Text = "Z" },
        [PSCustomObject]@{ Name = "TXT_KEY_X"; Text = "X" },
        [PSCustomObject]@{ Name = "TXT_KEY_M"; Text = "M" },
        [PSCustomObject]@{ Name = "TXT_KEY_N"; Text = "N" },
        [PSCustomObject]@{ Name = "TXT_KEY_SPACE"; Text = "SPACE" },
        [PSCustomObject]@{ Name = "TXT_KEY_CUR_L"; Text = "CUR L" },
        [PSCustomObject]@{ Name = "TXT_KEY_CUR_R"; Text = "CUR R" },
        [PSCustomObject]@{ Name = "TXT_KEY_CUR_U"; Text = "CUR U" },
        [PSCustomObject]@{ Name = "TXT_KEY_CUR_D"; Text = "CUR D" }
    )
}

function Get-OverlayKeyChoiceEntries {
    return @(
        [PSCustomObject]@{ KeyId = 0x0404; Name = "TXT_KEY_O" },
        [PSCustomObject]@{ KeyId = 0x0803; Name = "TXT_KEY_P" },
        [PSCustomObject]@{ KeyId = 0x0808; Name = "TXT_KEY_Q" },
        [PSCustomObject]@{ KeyId = 0x2008; Name = "TXT_KEY_A" },
        [PSCustomObject]@{ KeyId = 0x8008; Name = "TXT_KEY_Z" },
        [PSCustomObject]@{ KeyId = 0x8007; Name = "TXT_KEY_X" },
        [PSCustomObject]@{ KeyId = 0x4004; Name = "TXT_KEY_M" },
        [PSCustomObject]@{ KeyId = 0x4005; Name = "TXT_KEY_N" },
        [PSCustomObject]@{ KeyId = 0x8005; Name = "TXT_KEY_SPACE" },
        [PSCustomObject]@{ KeyId = 0x0101; Name = "TXT_KEY_CUR_L" },
        [PSCustomObject]@{ KeyId = 0x0200; Name = "TXT_KEY_CUR_R" },
        [PSCustomObject]@{ KeyId = 0x0100; Name = "TXT_KEY_CUR_U" },
        [PSCustomObject]@{ KeyId = 0x0400; Name = "TXT_KEY_CUR_D" }
    )
}

function New-RuntimeTextPayload {
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$HeaderPath,
        [Parameter(Mandatory = $true)][string]$MainSourcePath,
        [Parameter(Mandatory = $true)][int]$BaseAddress
    )

    $fontBytes = Get-FontGlyphBytes $MainSourcePath
    $gravityBytes = Get-U8TableBytes $MainSourcePath "gravityDelays" 100
    $lineScoreBytes = Get-U16TableBytes $MainSourcePath "lineScoreTable" 5
    $shapeBytes = Get-ShapeTableBytes $MainSourcePath
    $payloadBytes = New-Object System.Collections.Generic.List[byte]
    $payloadBytes.Add(0x46)
    $payloadBytes.Add(0x4E)
    $payloadBytes.Add(0x54)
    $payloadBytes.Add(0x35)
    Add-PayloadBytes $payloadBytes $fontBytes

    $header = New-Object System.Collections.Generic.List[string]
    $header.Add("#ifndef OVERLAY_TEXT_GENERATED_H")
    $header.Add("#define OVERLAY_TEXT_GENERATED_H")
    $header.Add("")

    $encoding = [System.Text.Encoding]::ASCII
    $textAddresses = @{}
    foreach ($entry in Get-OverlayTextEntries) {
        $address = $BaseAddress + $payloadBytes.Count
        $textAddresses[$entry.Name] = $address
        $header.Add(("#define {0} ((const char*)0x{1:X4})" -f $entry.Name, $address))
        foreach ($byte in $encoding.GetBytes($entry.Text)) {
            $payloadBytes.Add($byte)
        }
        $payloadBytes.Add(0)
    }

    $gravityAddress = $BaseAddress + $payloadBytes.Count
    $header.Add(("#define OVERLAY_GRAVITY_DELAYS ((const u8*)0x{0:X4})" -f $gravityAddress))
    Add-PayloadBytes $payloadBytes $gravityBytes

    if ((($BaseAddress + $payloadBytes.Count) % 2) -ne 0) {
        $payloadBytes.Add(0)
    }
    $lineScoreAddress = $BaseAddress + $payloadBytes.Count
    $header.Add(("#define OVERLAY_LINE_SCORE_TABLE ((const u16*)0x{0:X4})" -f $lineScoreAddress))
    Add-PayloadBytes $payloadBytes $lineScoreBytes

    $shapesAddress = $BaseAddress + $payloadBytes.Count
    $header.Add(("#define OVERLAY_SHAPES ((const u8*)0x{0:X4})" -f $shapesAddress))
    Add-PayloadBytes $payloadBytes $shapeBytes

    if ((($BaseAddress + $payloadBytes.Count) % 2) -ne 0) {
        $payloadBytes.Add(0)
    }
    $keyChoiceEntries = Get-OverlayKeyChoiceEntries
    $keyChoicesAddress = $BaseAddress + $payloadBytes.Count
    $header.Add(("#define OVERLAY_KEY_CHOICE_COUNT {0}" -f $keyChoiceEntries.Count))
    $header.Add(("#define OVERLAY_KEY_CHOICES ((const KeyChoice*)0x{0:X4})" -f $keyChoicesAddress))
    foreach ($entry in $keyChoiceEntries) {
        if (-not $textAddresses.ContainsKey($entry.Name)) {
            throw "No overlay text address found for key choice name $($entry.Name)."
        }
        Add-PayloadWord $payloadBytes $entry.KeyId
        Add-PayloadWord $payloadBytes $textAddresses[$entry.Name]
    }

    $header.Add("")
    $header.Add("#endif")
    Set-Content -Path $HeaderPath -Value $header -Encoding ascii

    $payload = $payloadBytes.ToArray()
    [System.IO.File]::WriteAllBytes(([System.IO.Path]::GetFullPath($OutputPath)), $payload)
    return [PSCustomObject]@{
        Path = $OutputPath
        Length = $payload.Length
        GlyphAddress = $BaseAddress + 4
        GravityAddress = $gravityAddress
        LineScoreAddress = $lineScoreAddress
        ShapesAddress = $shapesAddress
        KeyChoicesAddress = $keyChoicesAddress
    }
}

function New-RuntimeOverlayLayout {
    param(
        [Parameter(Mandatory = $true)][int]$SplashImageLength,
        [Parameter(Mandatory = $true)]$MusicOverlayInfo,
        [Parameter(Mandatory = $true)][int]$SplashAddress,
        [Parameter(Mandatory = $true)][int]$SplashStartTrack,
        [Parameter(Mandatory = $true)][int]$GameplayMusicAddress,
        [Parameter(Mandatory = $true)][int]$RuntimeFontLength,
        [Parameter(Mandatory = $true)][int]$MenuCodeAddress,
        [Parameter(Mandatory = $true)][int]$MenuCodeSectorCount
    )

    $splashTitleLength = $SplashImageLength + $MusicOverlayInfo.TitleMusicLength
    $splashTitleSectorCount = [int][Math]::Ceiling($splashTitleLength / $SectorSize)
    $splashTitleEndTrack = [int]($SplashStartTrack + [Math]::Floor(($splashTitleSectorCount - 1) / $SectorIds.Count))
    $gameplayMusicSectorCount = [int][Math]::Ceiling($MusicOverlayInfo.GameplayMusicLength / $SectorSize)
    $gameplayMusicTrack = $splashTitleEndTrack + 1
    $gameplayMusicEndTrack = [int]($gameplayMusicTrack + [Math]::Floor(($gameplayMusicSectorCount - 1) / $SectorIds.Count))
    $runtimeFontSectorCount = [int][Math]::Ceiling($runtimeFontLength / $SectorSize)
    $runtimeFontTrack = $gameplayMusicEndTrack + 1
    $runtimeFontEndTrack = [int]($runtimeFontTrack + [Math]::Floor(($runtimeFontSectorCount - 1) / $SectorIds.Count))
    $menuCodeTrack = $runtimeFontEndTrack + 1
    $menuCodeEndTrack = [int]($menuCodeTrack + [Math]::Floor(($MenuCodeSectorCount - 1) / $SectorIds.Count))

    if ($menuCodeEndTrack -gt 39) {
        throw "Menu code hidden sector would need track $menuCodeEndTrack, past the standard 40-track DSK range."
    }
    if (($SplashAddress + $splashTitleLength) -gt $GameplayMusicAddress) {
        throw ("Gameplay music address 0x{0:X4} overlaps splash/title overlay ending at 0x{1:X4}." -f $GameplayMusicAddress, ($SplashAddress + $splashTitleLength - 1))
    }
    if (($GameplayMusicAddress + $MusicOverlayInfo.GameplayMusicLength) -gt 0xA6FC) {
        throw ("Gameplay music address 0x{0:X4} is too close to firmware RAM." -f $GameplayMusicAddress)
    }

    New-RuntimeOverlayLoaderSource "tools\runtime_overlay_loader.s" "src\overlay\runtime_overlay_loader.generated.s" $SplashAddress $SplashStartTrack $splashTitleSectorCount $GameplayMusicAddress $gameplayMusicTrack $gameplayMusicSectorCount $SplashAddress $runtimeFontTrack $runtimeFontSectorCount $MenuCodeAddress $menuCodeTrack $MenuCodeSectorCount

    return [PSCustomObject]@{
        SplashTitleAddress = $SplashAddress
        SplashTitleTrack = $SplashStartTrack
        SplashTitleLength = $splashTitleLength
        SplashTitleSectorCount = $splashTitleSectorCount
        SplashTitleEndTrack = $splashTitleEndTrack
        GameplayMusicAddress = $GameplayMusicAddress
        GameplayMusicTrack = $gameplayMusicTrack
        GameplayMusicLength = $MusicOverlayInfo.GameplayMusicLength
        GameplayMusicSectorCount = $gameplayMusicSectorCount
        GameplayMusicEndTrack = $gameplayMusicEndTrack
        RuntimeFontAddress = $SplashAddress
        RuntimeFontTrack = $runtimeFontTrack
        RuntimeFontLength = $runtimeFontLength
        RuntimeFontSectorCount = $runtimeFontSectorCount
        RuntimeFontEndTrack = $runtimeFontEndTrack
        MenuCodeAddress = $MenuCodeAddress
        MenuCodeTrack = $menuCodeTrack
        MenuCodeSectorCount = $MenuCodeSectorCount
        MenuCodeEndTrack = $menuCodeEndTrack
    }
}

function Write-PayloadSectors {
    param(
        [Parameter(Mandatory = $true)][string]$DskPath,
        [Parameter(Mandatory = $true)][string]$PayloadPath,
        [Parameter(Mandatory = $true)][int]$StartTrack
    )

    $dsk = [System.IO.File]::ReadAllBytes((Resolve-Path $DskPath))
    $payload = [System.IO.File]::ReadAllBytes((Resolve-Path $PayloadPath))
    $sectorCount = [int][Math]::Ceiling($payload.Length / $SectorSize)
    $trackSize = [int]$dsk[0x32] + ([int]$dsk[0x33] -shl 8)
    if ($trackSize -eq 0) {
        throw "Unsupported DSK header: fixed track size is zero."
    }

    $payloadOffset = 0
    for ($i = 0; $i -lt $sectorCount; $i++) {
        $track = [int]($StartTrack + [Math]::Floor($i / $SectorIds.Count))
        $sectorId = [int]$SectorIds[$i % $SectorIds.Count]
        $trackOffset = 0x100 + ($track * $trackSize)
        if ($trackOffset + 0x100 -gt $dsk.Length) {
            throw "Overlay payload reaches past the end of the DSK at track $track."
        }

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
                $copyLen = [Math]::Min($SectorSize, $payload.Length - $payloadOffset)
                for ($j = 0; $j -lt $SectorSize; $j++) {
                    $dsk[$dataOffset + $j] = 0
                }
                [Array]::Copy($payload, $payloadOffset, $dsk, $dataOffset, $copyLen)
                $payloadOffset += $copyLen
                $found = $true
                break
            }

            $dataOffset += $size
        }

        if (-not $found) {
            throw ("Could not find sector 0x{0:X2} on track {1}." -f $sectorId, $track)
        }
    }

    [System.IO.File]::WriteAllBytes((Resolve-Path $DskPath), $dsk)
    return $sectorCount
}

function Test-PayloadSectors {
    param(
        [Parameter(Mandatory = $true)][string]$DskPath,
        [Parameter(Mandatory = $true)][string]$PayloadPath,
        [Parameter(Mandatory = $true)][int]$StartTrack
    )

    $dsk = [System.IO.File]::ReadAllBytes((Resolve-Path $DskPath))
    $payload = [System.IO.File]::ReadAllBytes((Resolve-Path $PayloadPath))
    $sectorCount = [int][Math]::Ceiling($payload.Length / $SectorSize)
    $trackSize = [int]$dsk[0x32] + ([int]$dsk[0x33] -shl 8)
    $readBack = New-Object byte[] ($sectorCount * $SectorSize)
    $outOffset = 0

    for ($i = 0; $i -lt $sectorCount; $i++) {
        $track = [int]($StartTrack + [Math]::Floor($i / $SectorIds.Count))
        $sectorId = [int]$SectorIds[$i % $SectorIds.Count]
        $trackOffset = 0x100 + ($track * $trackSize)
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
                [Array]::Copy($dsk, $dataOffset, $readBack, $outOffset, $SectorSize)
                $outOffset += $SectorSize
                $found = $true
                break
            }

            $dataOffset += $size
        }

        if (-not $found) {
            throw ("Could not verify sector 0x{0:X2} on track {1}." -f $sectorId, $track)
        }
    }

    for ($i = 0; $i -lt $payload.Length; $i++) {
        if ($payload[$i] -ne $readBack[$i]) {
            throw "Overlay verification failed at payload byte $i."
        }
    }

    for ($i = $payload.Length; $i -lt $readBack.Length; $i++) {
        if ($readBack[$i] -ne 0) {
            throw "Overlay verification failed in padding byte $i."
        }
    }
}

function Get-MapSymbolAddress {
    param(
        [Parameter(Mandatory = $true)][string]$MapPath,
        [Parameter(Mandatory = $true)][string]$Symbol
    )

    $pattern = "^\s*([0-9A-Fa-f]{8})\s+$([regex]::Escape($Symbol))\b"
    foreach ($line in Get-Content $MapPath) {
        if ($line -match $pattern) {
            return [Convert]::ToInt32($matches[1], 16)
        }
    }
    throw "Could not find symbol $Symbol in $MapPath."
}

function Get-MainSymAddress {
    param(
        [Parameter(Mandatory = $true)][string]$SymPath,
        [Parameter(Mandatory = $true)][string]$Symbol,
        [Parameter(Mandatory = $true)][int]$CodeBase,
        [Parameter(Mandatory = $true)][int]$DataBase
    )

    $pattern = "^\s*([01])\s+$([regex]::Escape($Symbol))\s+([0-9A-Fa-f]{4})\s+R\b"
    foreach ($line in Get-Content $SymPath) {
        if ($line -match $pattern) {
            $area = [int]$matches[1]
            $offset = [Convert]::ToInt32($matches[2], 16)
            if ($area -eq 0) {
                return $CodeBase + $offset
            }
            return $DataBase + $offset
        }
    }
    throw "Could not find resident symbol $Symbol in $SymPath."
}

function New-MenuOverlayBindings {
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$MapPath,
        [Parameter(Mandatory = $true)][string]$SymPath
    )

    $codeBase = Get-MapSymbolAddress $MapPath "s__CODE"
    $dataBase = Get-MapSymbolAddress $MapPath "s__DATA"
    $bindings = New-Object System.Collections.Generic.List[string]
    $bindings.Add(".area _CODE")

    foreach ($symbol in @("_drawText", "_waitReleased", "_randomPiece")) {
        $address = Get-MainSymAddress $SymPath $symbol $codeBase $dataBase
        $bindings.Add(".globl $symbol")
        $bindings.Add(("{0} = #0x{1:X4}" -f $symbol, $address))
    }

    foreach ($symbol in @("_music_stop", "_cpct_waitVSYNC", "_cpct_scanKeyboard_f", "_cpct_isKeyPressed", "_cpct_memset")) {
        $address = Get-MapSymbolAddress $MapPath $symbol
        $bindings.Add(".globl $symbol")
        $bindings.Add(("{0} = #0x{1:X4}" -f $symbol, $address))
    }

    foreach ($symbol in @("_cellPattern", "_keyLeft", "_keyRight", "_keyRotate", "_keyDown", "_keyDrop")) {
        $address = Get-MainSymAddress $SymPath $symbol $codeBase $dataBase
        $bindings.Add(".globl $symbol")
        $bindings.Add(("{0} = #0x{1:X4}" -f $symbol, $address))
    }

    Set-Content -Path $OutputPath -Value $bindings -Encoding ascii
}

function New-PaddedBinary {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][int]$PaddedLength
    )

    $inputBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $InputPath))
    if ($inputBytes.Length -gt $PaddedLength) {
        throw ("{0} is {1} bytes, exceeding reserved overlay size {2} bytes." -f $InputPath, $inputBytes.Length, $PaddedLength)
    }
    $outputBytes = New-Object byte[] $PaddedLength
    [Array]::Copy($inputBytes, 0, $outputBytes, 0, $inputBytes.Length)
    [System.IO.File]::WriteAllBytes(([System.IO.Path]::GetFullPath($OutputPath)), $outputBytes)
    return [PSCustomObject]@{
        Path = $OutputPath
        Length = $inputBytes.Length
        PaddedLength = $PaddedLength
    }
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

    New-Item -ItemType Directory -Force -Path "dist" | Out-Null
    Remove-Item -Force -ErrorAction SilentlyContinue "dist\TETRIS.BAS", "dist\TETRIS-$ReleaseVersion.BAS"
    Remove-Item -Force -ErrorAction SilentlyContinue "dist\TETRIS.CDT", "dist\TETRIS-$ReleaseVersion.CDT"
    Remove-Item -Force -ErrorAction SilentlyContinue "dist\GAME.DAT", "dist\GAME-$ReleaseVersion.DAT"

    $cygRoot = Convert-ToCygwinPath $Root.Path
    $cygCpct = Convert-ToCygwinPath $cpctPath
    $splashImageLength = Get-SplashImageLength "src\splash.h"
    $titleMusicAddress = $SplashAddress + $splashImageLength

    if (-not $SkipGameBuild) {
        $cleanCmd = "cd '$cygRoot' && export CPCT_PATH='$cygCpct' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/iDSK-0.13/bin:$cygCpct/tools/hex2bin-2.0/bin:$cygCpct/tools/2cdt/bin:$cygCpct/tools/dskgen/bin':`$PATH && make clean"
        & $LocalBash -lc $cleanCmd
        if ($LASTEXITCODE -ne 0) {
            throw "CPCtelera make clean failed with exit code $LASTEXITCODE."
        }

        New-Item -ItemType Directory -Force -Path "src\overlay" | Out-Null
        New-Item -ItemType Directory -Force -Path "obj\overlay" | Out-Null
        $musicOverlayInfo = New-OverlayMusicSources "src\music.s" "src\overlay\music_overlay.generated.s" "obj\overlay\title_music_overlay.generated.s" "obj\overlay\gameplay_music_overlay.generated.s" $titleMusicAddress $GameplayMusicAddress
        $runtimeTextInfo = New-RuntimeTextPayload "obj\overlay\runtime_font_overlay.bin" "src\overlay\overlay_text.generated.h" "src\main.c" $SplashAddress
        $overlayLayout = New-RuntimeOverlayLayout $splashImageLength $musicOverlayInfo $SplashAddress $SplashStartTrack $GameplayMusicAddress $runtimeTextInfo.Length $MenuCodeAddress $MenuCodeSectorCount

        $buildCmd = "cd '$cygRoot' && export CPCT_PATH='$cygCpct' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/iDSK-0.13/bin:$cygCpct/tools/hex2bin-2.0/bin:$cygCpct/tools/2cdt/bin:$cygCpct/tools/dskgen/bin':`$PATH && make OVERLAY_SPLASH=1 MENU_CODE_OVERLAY=1"
        & $LocalBash -lc $buildCmd
        if ($LASTEXITCODE -ne 0) {
            throw "CPCtelera make failed with exit code $LASTEXITCODE."
        }
    } else {
        New-Item -ItemType Directory -Force -Path "src\overlay" | Out-Null
        New-Item -ItemType Directory -Force -Path "obj\overlay" | Out-Null
        $musicOverlayInfo = New-OverlayMusicSources "src\music.s" "src\overlay\music_overlay.generated.s" "obj\overlay\title_music_overlay.generated.s" "obj\overlay\gameplay_music_overlay.generated.s" $titleMusicAddress $GameplayMusicAddress
        $runtimeTextInfo = New-RuntimeTextPayload "obj\overlay\runtime_font_overlay.bin" "src\overlay\overlay_text.generated.h" "src\main.c" $SplashAddress
        $overlayLayout = New-RuntimeOverlayLayout $splashImageLength $musicOverlayInfo $SplashAddress $SplashStartTrack $GameplayMusicAddress $runtimeTextInfo.Length $MenuCodeAddress $MenuCodeSectorCount
    }

    $payloadPath = "obj\TETRIS.bin"
    if (-not (Test-Path $payloadPath)) {
        throw "Missing $payloadPath. Run without -SkipGameBuild first."
    }

    $loadAddress = Read-HexAddressFromLog "obj\binaryAddresses.log" "Load Address"
    $runAddress = Read-HexAddressFromLog "obj\binaryAddresses.log" "Run\s+Address"
    $highestAddress = Read-HexAddressFromLog "obj\TETRIS.bin.log" "Highest address"
    $payloadLength = (Get-Item $payloadPath).Length
    $payloadSectorCount = [int][Math]::Ceiling($payloadLength / $SectorSize)
    $workspaceTop = $SplashAddress - 1
    $workspaceGuard = $workspaceTop - 0x0600
    if ($highestAddress -ge $workspaceGuard) {
        throw ("Payload highest address 0x{0:X4} is too close to overlay workspace below 0x{1:X4}." -f $highestAddress, $SplashAddress)
    }

    New-Item -ItemType Directory -Force -Path "obj\overlay" | Out-Null

    New-MenuOverlayBindings "obj\overlay\menu_overlay_bindings.s" "obj\TETRIS.map" "obj\main.sym"
    $menuOverlayCmd = "cd '$cygRoot' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/hex2bin-2.0/bin':`$PATH && sdcc -mz80 --no-std-crt0 -I'$cygCpct/src' -Isrc -c tools/menu_overlay.c -o obj/overlay/menu_overlay.rel && sdasz80 -l -o -s obj/overlay/menu_overlay_entry.rel tools/menu_overlay_entry.s && sdasz80 -l -o -s obj/overlay/menu_overlay_bindings.rel obj/overlay/menu_overlay_bindings.s && sdcc -mz80 --no-std-crt0 --code-loc $('0x{0:X4}' -f $MenuCodeAddress) --data-loc 0 obj/overlay/menu_overlay_entry.rel obj/overlay/menu_overlay.rel obj/overlay/menu_overlay_bindings.rel -o obj/overlay/menu_overlay.ihx && hex2bin -p 00 obj/overlay/menu_overlay.ihx"
    & $LocalBash -lc $menuOverlayCmd
    if ($LASTEXITCODE -ne 0) {
        throw "Menu code overlay build failed with exit code $LASTEXITCODE."
    }
    $menuOverlayInfo = New-PaddedBinary "obj\overlay\menu_overlay.bin" "obj\overlay\menu_overlay.padded.bin" ($MenuCodeSectorCount * $SectorSize)

    $splashSource = Get-Content -Raw "src\splash.s"
    if ($splashSource -notmatch "\.area\s+_DATA") {
        $splashSource = ".area _DATA`r`n`r`n" + $splashSource
    }
    Set-Content -Path "obj\overlay\splash_overlay.generated.s" -Value $splashSource -Encoding ascii

    $splashCmd = "cd '$cygRoot' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/hex2bin-2.0/bin':`$PATH && sdasz80 -l -o -s obj/overlay/splash_overlay.rel obj/overlay/splash_overlay.generated.s && sdcc -mz80 --no-std-crt0 --code-loc $('0x{0:X4}' -f $SplashAddress) --data-loc 0 obj/overlay/splash_overlay.rel -o obj/overlay/splash_overlay.ihx && hex2bin -p 00 obj/overlay/splash_overlay.ihx"
    & $LocalBash -lc $splashCmd
    if ($LASTEXITCODE -ne 0) {
        throw "Splash overlay build failed with exit code $LASTEXITCODE."
    }

    $titleMusicCmd = "cd '$cygRoot' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/hex2bin-2.0/bin':`$PATH && sdasz80 -l -o -s obj/overlay/title_music_overlay.rel obj/overlay/title_music_overlay.generated.s && sdcc -mz80 --no-std-crt0 --code-loc $('0x{0:X4}' -f $titleMusicAddress) --data-loc 0 obj/overlay/title_music_overlay.rel -o obj/overlay/title_music_overlay.ihx && hex2bin -p 00 obj/overlay/title_music_overlay.ihx"
    & $LocalBash -lc $titleMusicCmd
    if ($LASTEXITCODE -ne 0) {
        throw "Title music overlay build failed with exit code $LASTEXITCODE."
    }

    $gameplayMusicCmd = "cd '$cygRoot' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/hex2bin-2.0/bin':`$PATH && sdasz80 -l -o -s obj/overlay/gameplay_music_overlay.rel obj/overlay/gameplay_music_overlay.generated.s && sdcc -mz80 --no-std-crt0 --code-loc $('0x{0:X4}' -f $GameplayMusicAddress) --data-loc 0 obj/overlay/gameplay_music_overlay.rel -o obj/overlay/gameplay_music_overlay.ihx && hex2bin -p 00 obj/overlay/gameplay_music_overlay.ihx"
    & $LocalBash -lc $gameplayMusicCmd
    if ($LASTEXITCODE -ne 0) {
        throw "Gameplay music overlay build failed with exit code $LASTEXITCODE."
    }

    $splashImagePath = "obj\overlay\splash_overlay.bin"
    $titleMusicPath = "obj\overlay\title_music_overlay.bin"
    $gameplayMusicPath = "obj\overlay\gameplay_music_overlay.bin"
    $splashPath = "obj\overlay\splash_title_segment.bin"
    Join-BinaryFiles $splashImagePath $titleMusicPath $splashPath

    $splashLength = (Get-Item $splashPath).Length
    $titleMusicDataLength = (Get-Item $titleMusicPath).Length
    $gameplayMusicDataLength = (Get-Item $gameplayMusicPath).Length
    $splashSectorCount = [int][Math]::Ceiling($splashLength / $SectorSize)
    $gameplayMusicSectorCount = [int][Math]::Ceiling($gameplayMusicDataLength / $SectorSize)
    if ($splashSectorCount -ne $overlayLayout.SplashTitleSectorCount) {
        throw "Generated splash/title loader sector count does not match assembled overlay size."
    }
    if ($gameplayMusicSectorCount -ne $overlayLayout.GameplayMusicSectorCount) {
        throw "Generated gameplay music loader sector count does not match assembled overlay size."
    }
    $payloadEndTrack = [int]($PayloadStartTrack + [Math]::Floor(($payloadSectorCount - 1) / $SectorIds.Count))
    if ($payloadEndTrack -ge $SplashStartTrack) {
        throw "Payload sectors $PayloadStartTrack-$payloadEndTrack overlap splash start track $SplashStartTrack."
    }

    if ($DirectFdcBoot -and $AmsdosBoot) {
        throw "Use either -DirectFdcBoot or -AmsdosBoot, not both."
    }
    $bootLoaderTemplate = if ($AmsdosBoot) {
        "tools\overlay_sector_loader.s"
    } else {
        "tools\overlay_sector_loader_direct_fdc.s"
    }
    New-OverlayLoaderSource $bootLoaderTemplate "obj\overlay\overlay_sector_loader.generated.s" $loadAddress $runAddress $payloadSectorCount $PayloadStartTrack $workspaceTop

    $asmCmd = "cd '$cygRoot' && export PATH='$cygCpct/tools/sdcc-3.6.8-r9946/bin:$cygCpct/tools/hex2bin-2.0/bin:$cygCpct/tools/iDSK-0.13/bin':`$PATH && sdasz80 -l -o -s obj/overlay/overlay_sector_loader.rel obj/overlay/overlay_sector_loader.generated.s && sdcc -mz80 --no-std-crt0 --code-loc $('0x{0:X4}' -f $LoaderLoadAddress) --data-loc 0 obj/overlay/overlay_sector_loader.rel -o obj/overlay/overlay_sector_loader.ihx && hex2bin -p 00 obj/overlay/overlay_sector_loader.ihx"
    & $LocalBash -lc $asmCmd
    if ($LASTEXITCODE -ne 0) {
        throw "Overlay loader build failed with exit code $LASTEXITCODE."
    }

    Copy-Item -Force "obj\overlay\overlay_sector_loader.bin" "obj\overlay\TETRIS.BIN"
    Write-AmsdosBinary "obj\overlay\overlay_sector_loader.bin" "dist\TETRIS.BIN" $LoaderLoadAddress $LoaderLoadAddress "TETRIS.BIN"
    Copy-Item -Force "dist\TETRIS.BIN" "dist\TETRIS-$ReleaseVersion.BIN"
    Remove-Item -Force -ErrorAction SilentlyContinue $OutputDsk

    $cygOutputDsk = Convert-ToCygwinPath $OutputDsk
    $idskCmd = "cd '$cygRoot' && export PATH='$cygCpct/tools/iDSK-0.13/bin':`$PATH && iDSK '$cygOutputDsk' -n && iDSK '$cygOutputDsk' -i obj/overlay/TETRIS.BIN -e $('{0:X4}' -f $LoaderLoadAddress) -c $('{0:X4}' -f $LoaderLoadAddress) -t 1 -f"
    & $LocalBash -lc $idskCmd
    if ($LASTEXITCODE -ne 0) {
        throw "Overlay DSK creation failed with exit code $LASTEXITCODE."
    }

    $writtenSectorCount = Write-PayloadSectors $OutputDsk $payloadPath $PayloadStartTrack
    $writtenSplashSectorCount = Write-PayloadSectors $OutputDsk $splashPath $SplashStartTrack
    $writtenGameplayMusicSectorCount = Write-PayloadSectors $OutputDsk $gameplayMusicPath $overlayLayout.GameplayMusicTrack
    $runtimeFontPath = $runtimeTextInfo.Path
    if ($runtimeTextInfo.Length -ne $overlayLayout.RuntimeFontLength) {
        throw "Generated runtime text/font length does not match overlay layout."
    }
    $writtenRuntimeFontSectorCount = Write-PayloadSectors $OutputDsk $runtimeFontPath $overlayLayout.RuntimeFontTrack
    $writtenMenuCodeSectorCount = Write-PayloadSectors $OutputDsk $menuOverlayInfo.Path $overlayLayout.MenuCodeTrack
    Test-PayloadSectors $OutputDsk $payloadPath $PayloadStartTrack
    Test-PayloadSectors $OutputDsk $splashPath $SplashStartTrack
    Test-PayloadSectors $OutputDsk $gameplayMusicPath $overlayLayout.GameplayMusicTrack
    Test-PayloadSectors $OutputDsk $runtimeFontPath $overlayLayout.RuntimeFontTrack
    Test-PayloadSectors $OutputDsk $menuOverlayInfo.Path $overlayLayout.MenuCodeTrack

    $endTrack = [int]($PayloadStartTrack + [Math]::Floor(($writtenSectorCount - 1) / $SectorIds.Count))
    $splashEndTrack = [int]($SplashStartTrack + [Math]::Floor(($writtenSplashSectorCount - 1) / $SectorIds.Count))
    $gameplayMusicEndTrack = [int]($overlayLayout.GameplayMusicTrack + [Math]::Floor(($writtenGameplayMusicSectorCount - 1) / $SectorIds.Count))
    Write-Host ("Overlay DSK: {0}" -f (Resolve-Path $OutputDsk))
    Write-Host ("Boot loader template: {0}" -f $bootLoaderTemplate)
    Write-Host ("Loader: load/run 0x{0:X4}; size {1} bytes" -f $LoaderLoadAddress, (Get-Item "obj\overlay\overlay_sector_loader.bin").Length)
    Write-Host ("Payload: load 0x{0:X4}; run 0x{1:X4}; highest 0x{2:X4}; bytes {3}; sectors {4}; tracks {5}-{6}" -f $loadAddress, $runAddress, $highestAddress, $payloadLength, $writtenSectorCount, $PayloadStartTrack, $endTrack)
    Write-Host ("Runtime splash/title overlay: load 0x{0:X4}; bytes {1}; sectors {2}; tracks {3}-{4}" -f $SplashAddress, $splashLength, $writtenSplashSectorCount, $SplashStartTrack, $splashEndTrack)
    Write-Host ("Runtime gameplay music overlay: load 0x{0:X4}; bytes {1}; sectors {2}; tracks {3}-{4}" -f $GameplayMusicAddress, $gameplayMusicDataLength, $writtenGameplayMusicSectorCount, $overlayLayout.GameplayMusicTrack, $gameplayMusicEndTrack)
    Write-Host ("Runtime font/text/tables overlay: load 0x{0:X4}; glyphs at 0x{1:X4}; shapes at 0x{2:X4}; keys at 0x{3:X4}; bytes {4}; sectors {5}; tracks {6}-{7}" -f $overlayLayout.RuntimeFontAddress, $runtimeTextInfo.GlyphAddress, $runtimeTextInfo.ShapesAddress, $runtimeTextInfo.KeyChoicesAddress, $overlayLayout.RuntimeFontLength, $writtenRuntimeFontSectorCount, $overlayLayout.RuntimeFontTrack, $overlayLayout.RuntimeFontEndTrack)
    Write-Host ("Runtime menu code overlay: load 0x{0:X4}; bytes {1}; padded {2}; sectors {3}; tracks {4}-{5}" -f $overlayLayout.MenuCodeAddress, $menuOverlayInfo.Length, $menuOverlayInfo.PaddedLength, $writtenMenuCodeSectorCount, $overlayLayout.MenuCodeTrack, $overlayLayout.MenuCodeEndTrack)
    Write-Host ("Title music data: load 0x{0:X4}; bytes {1}" -f $musicOverlayInfo.TitleMusicAddress, $musicOverlayInfo.TitleMusicLength)
    Write-Host ("Gameplay music data: load 0x{0:X4}; bytes {1}" -f $musicOverlayInfo.GameplayMusicAddress, $musicOverlayInfo.GameplayMusicLength)
    Write-Host ("Runtime title music bytes: {0}" -f $titleMusicDataLength)
    Write-Host ("Persistent gameplay music bytes: {0}" -f $gameplayMusicDataLength)
    Copy-IfDifferent $OutputDsk "dist\TETRIS.DSK"
    Copy-Item -Force $OutputDsk "dist\TETRIS-$ReleaseVersion.DSK"
    Write-Host ("Release BIN: {0}" -f (Resolve-Path "dist\TETRIS.BIN"))
    Write-Host ("Release DSK: {0}" -f (Resolve-Path "dist\TETRIS.DSK"))
    Write-Host ("Versioned DSK: {0}" -f (Resolve-Path "dist\TETRIS-$ReleaseVersion.DSK"))
} finally {
    Pop-Location
}
