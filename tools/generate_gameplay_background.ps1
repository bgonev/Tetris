param(
    [string]$SourcePath = "assets\new_gameplay_layout.jpg",
    [string]$OutputBin = "obj\overlay\gameplay_screen.bin",
    [string]$PreviewPath = "assets\gameplay_mode0_preview.png"
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$SourcePath = Join-Path $Root.Path $SourcePath
$OutputBin = Join-Path $Root.Path $OutputBin
$PreviewPath = Join-Path $Root.Path $PreviewPath

Add-Type -AssemblyName System.Drawing

$width = 160
$height = 200
$mode0WidthBytes = 80
$screenSize = 0x4000
$displayWidth = 320

# Keep this palette in the same logical ink order used by src/main.c.
$palette = @(
    @(0, 0, 220),       # 0 blue
    @(0, 255, 255),     # 1 bright cyan
    @(255, 255, 0),     # 2 bright yellow
    @(0, 128, 255),     # 3 sky blue
    @(255, 255, 128),   # 4 pastel yellow
    @(128, 255, 128),   # 5 pastel green
    @(255, 128, 128),   # 6 pink
    @(255, 128, 255),   # 7 pastel magenta
    @(160, 160, 160),   # 8 white/stone grey
    @(255, 255, 255),   # 9 bright white
    @(128, 128, 255),   # 10 pastel blue
    @(0, 255, 0),       # 11 bright green
    @(192, 192, 0),     # 12 yellow
    @(255, 128, 0),     # 13 orange
    @(255, 0, 0),       # 14 bright red
    @(0, 0, 0)          # 15 black
)

$mode0Table = @(0x00, 0x40, 0x04, 0x44, 0x10, 0x50, 0x14, 0x54, 0x01, 0x41, 0x05, 0x45, 0x11, 0x51, 0x15, 0x55)

function Get-NearestPaletteIndex {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Color]$Color,
        [Parameter(Mandatory = $true)][object[]]$Palette
    )

    $bestIndex = 0
    $bestDistance = [double]::MaxValue
    for ($i = 0; $i -lt $Palette.Length; $i++) {
        $entry = $Palette[$i]
        $dr = [double]$Color.R - [double]$entry[0]
        $dg = [double]$Color.G - [double]$entry[1]
        $db = [double]$Color.B - [double]$entry[2]
        $distance = 0.30 * $dr * $dr + 0.59 * $dg * $dg + 0.11 * $db * $db
        if ($distance -lt $bestDistance) {
            $bestDistance = $distance
            $bestIndex = $i
        }
    }
    return $bestIndex
}

function Set-PixelIndex {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Indexes,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][int]$Ink,
        [int]$ScaleY = 1
    )

    if ($X -ge 0 -and $X -lt $script:width -and $Y -ge 0 -and $Y -lt $script:height) {
        $Indexes[$Y * $script:width + $X] = [byte]$Ink
    }
}

function Fill-Rect {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Indexes,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][int]$W,
        [Parameter(Mandatory = $true)][int]$H,
        [Parameter(Mandatory = $true)][int]$Ink
    )

    for ($yy = $Y; $yy -lt $Y + $H; $yy++) {
        for ($xx = $X; $xx -lt $X + $W; $xx++) {
            Set-PixelIndex $Indexes $xx $yy $Ink
        }
    }
}

function Stroke-Rect {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Indexes,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][int]$W,
        [Parameter(Mandatory = $true)][int]$H,
        [Parameter(Mandatory = $true)][int]$Ink
    )

    Fill-Rect $Indexes $X $Y $W 1 $Ink
    Fill-Rect $Indexes $X ($Y + $H - 1) $W 1 $Ink
    Fill-Rect $Indexes $X $Y 1 $H $Ink
    Fill-Rect $Indexes ($X + $W - 1) $Y 1 $H $Ink
}

function Fill-Bricks {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Indexes,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][int]$W,
        [Parameter(Mandatory = $true)][int]$H
    )

    Fill-Rect $Indexes $X $Y $W $H 8
    for ($yy = $Y; $yy -lt $Y + $H; $yy += 4) {
        Fill-Rect $Indexes $X $yy $W 1 15
    }
    for ($yy = $Y + 1; $yy -lt $Y + $H; $yy += 4) {
        $offset = if (([int](($yy - $Y) / 4) % 2) -eq 0) { 0 } else { 4 }
        for ($xx = $X + $offset; $xx -lt $X + $W; $xx += 8) {
            Fill-Rect $Indexes $xx $yy 1 3 15
        }
    }
    Stroke-Rect $Indexes $X $Y $W $H 15
    Stroke-Rect $Indexes ($X + 1) ($Y + 1) ($W - 2) ($H - 2) 9
}

function Draw-Tower {
    param([Parameter(Mandatory = $true)][byte[]]$Indexes)

    Fill-Rect $Indexes 128 54 22 56 15
    Stroke-Rect $Indexes 128 54 22 56 8
    Stroke-Rect $Indexes 130 56 18 52 9
    for ($yy = 60; $yy -lt 106; $yy += 4) {
        Fill-Rect $Indexes 131 $yy 16 1 8
    }
    Stroke-Rect $Indexes 133 66 5 16 8
    Stroke-Rect $Indexes 141 66 5 16 8
    Stroke-Rect $Indexes 133 88 5 18 8
    Stroke-Rect $Indexes 141 88 5 18 8
    Fill-Rect $Indexes 135 68 2 12 0
    Fill-Rect $Indexes 143 68 2 12 0
    Fill-Rect $Indexes 135 90 2 14 0
    Fill-Rect $Indexes 143 90 2 14 0

    Fill-Rect $Indexes 122 49 34 7 15
    Stroke-Rect $Indexes 122 49 34 7 8
    for ($row = 0; $row -lt 20; $row++) {
        $y = 29 + $row
        $half = [int][Math]::Floor((20 - [Math]::Abs(10 - $row)) * 0.9)
        $x0 = 139 - $half
        $w = $half * 2
        if ($w -gt 0) {
            Fill-Rect $Indexes $x0 $y $w 1 11
            if ($row -gt 3 -and $row -lt 18) {
                Fill-Rect $Indexes ($x0 + 5) $y 5 1 2
                Fill-Rect $Indexes ($x0 + 14) $y 4 1 12
                Fill-Rect $Indexes ($x0 + $w - 7) $y 4 1 3
            }
        }
    }
    Stroke-Rect $Indexes 128 35 28 13 15
    Fill-Rect $Indexes 138 20 2 10 8
    Fill-Rect $Indexes 136 24 6 2 9
}

function Draw-Left-Building {
    param([Parameter(Mandatory = $true)][byte[]]$Indexes)

    Fill-Rect $Indexes 0 104 48 18 15
    Fill-Rect $Indexes 0 118 48 2 8
    Fill-Rect $Indexes 0 120 48 2 9
    Fill-Bricks $Indexes 0 124 48 56
    Stroke-Rect $Indexes 0 124 48 56 15
    Stroke-Rect $Indexes 8 146 9 22 8
    Stroke-Rect $Indexes 29 146 9 22 8
    Fill-Rect $Indexes 11 150 3 18 15
    Fill-Rect $Indexes 32 150 3 18 15
    Stroke-Rect $Indexes 3 135 6 7 9
    Stroke-Rect $Indexes 17 135 6 7 9
    Stroke-Rect $Indexes 31 135 6 7 9
}

function Draw-Text {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][System.Drawing.Color]$Color,
        [int]$Size = 10
    )

    $graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::SingleBitPerPixelGridFit
    $font = New-Object System.Drawing.Font "Consolas", $Size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $brush = New-Object System.Drawing.SolidBrush $Color
    $graphics.DrawString($Text, $font, $brush, $X, $Y)
    $brush.Dispose()
    $font.Dispose()
    $graphics.Dispose()
}

function Draw-SpriteText {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Indexes,
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][int]$Ink,
        [int]$ScaleY = 1
    )

    $glyphs = @{
        "E" = @(0xF,0x8,0x8,0xE,0x8,0x8,0xF)
        "I" = @(0xE,0x4,0x4,0x4,0x4,0x4,0xE)
        "N" = @(0x9,0xD,0xD,0xB,0xB,0x9,0x9)
        "R" = @(0xE,0x9,0x9,0xE,0xC,0xA,0x9)
        "S" = @(0x7,0x8,0x8,0x6,0x1,0x1,0xE)
        "T" = @(0xF,0x4,0x4,0x4,0x4,0x4,0x4)
        "X" = @(0x9,0x9,0x6,0x6,0x6,0x9,0x9)
    }

    $cursorX = $X
    foreach ($ch in $Text.ToCharArray()) {
        $key = [string]$ch
        if ($glyphs.ContainsKey($key)) {
            $rows = $glyphs[$key]
            for ($row = 0; $row -lt 7; $row++) {
                $bits = $rows[$row]
                for ($col = 0; $col -lt 4; $col++) {
                    if (($bits -band (1 -shl (3 - $col))) -ne 0) {
                        for ($sy = 0; $sy -lt $ScaleY; $sy++) {
                            Set-PixelIndex $Indexes ($cursorX + $col) ($Y + $row * $ScaleY + $sy) $Ink
                        }
                    }
                }
            }
        }
        $cursorX += 4
    }
}

function Get-ScreenOffset {
    param(
        [Parameter(Mandatory = $true)][int]$XByte,
        [Parameter(Mandatory = $true)][int]$Y
    )

    return (($Y -band 7) * 0x800) + ([int][Math]::Floor($Y / 8) * 80) + $XByte
}

if (-not (Test-Path $SourcePath)) {
    throw "Missing gameplay mock source image: $SourcePath"
}

New-Item -ItemType Directory -Force -Path (Split-Path $OutputBin) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $PreviewPath) | Out-Null

$source = [System.Drawing.Image]::FromFile((Resolve-Path $SourcePath))
$scaled = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($scaled)
$graphics.Clear([System.Drawing.Color]::Blue)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$graphics.DrawImage($source, 0, 0, $width, $height)
$graphics.Dispose()
$source.Dispose()

$indexes = New-Object byte[] ($width * $height)
for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        $indexes[$y * $width + $x] = [byte](Get-NearestPaletteIndex ($scaled.GetPixel($x, $y)) $palette)
    }
}
$scaled.Dispose()

# Rebuild the critical live-game areas at CPC resolution so the board and HUD
# remain readable even if the downscaled mock has thin details.
Fill-Rect $indexes 0 0 116 13 0
Fill-Rect $indexes 0 0 48 104 0
Draw-Left-Building $indexes
Fill-Bricks $indexes 48 13 64 177
Stroke-Rect $indexes 54 17 52 169 15
Stroke-Rect $indexes 55 18 50 167 9
Fill-Rect $indexes 60 20 40 160 15
Stroke-Rect $indexes 58 18 44 164 8
Stroke-Rect $indexes 57 17 46 166 9

Fill-Rect $indexes 116 108 40 55 15
Stroke-Rect $indexes 116 108 40 55 8
Stroke-Rect $indexes 118 110 36 51 9
Fill-Rect $indexes 120 128 32 32 15
Draw-SpriteText $indexes "NEXT" 128 114 9 -ScaleY 1

Fill-Rect $indexes 5 180 44 16 15
Stroke-Rect $indexes 5 180 44 16 8
Stroke-Rect $indexes 7 182 40 12 9
Draw-SpriteText $indexes "TETRIS" 15 185 9 -ScaleY 1

$preview = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        $pal = $palette[$indexes[$y * $width + $x]]
        $preview.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($pal[0], $pal[1], $pal[2]))
    }
}
for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        $indexes[$y * $width + $x] = [byte](Get-NearestPaletteIndex ($preview.GetPixel($x, $y)) $palette)
    }
}

$screen = New-Object byte[] $screenSize
for ($y = 0; $y -lt $height; $y++) {
    for ($xb = 0; $xb -lt $mode0WidthBytes; $xb++) {
        $left = $indexes[$y * $width + $xb * 2]
        $right = $indexes[$y * $width + $xb * 2 + 1]
        $screen[(Get-ScreenOffset $xb $y)] = [byte]((($mode0Table[$left] -shl 1) -bor $mode0Table[$right]) -band 0xFF)
    }
}
[System.IO.File]::WriteAllBytes($OutputBin, $screen)

$displayPreview = New-Object System.Drawing.Bitmap $displayWidth, $height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$displayGraphics = [System.Drawing.Graphics]::FromImage($displayPreview)
$displayGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$displayGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$displayGraphics.DrawImage($preview, 0, 0, $displayWidth, $height)
$displayGraphics.Dispose()
$displayPreview.Save($PreviewPath, [System.Drawing.Imaging.ImageFormat]::Png)
$displayPreview.Dispose()
$preview.Dispose()

Write-Host "Generated $OutputBin"
Write-Host "Generated $PreviewPath"
