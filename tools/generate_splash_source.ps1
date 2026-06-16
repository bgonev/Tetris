$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$OutPath = Join-Path $Root.Path "assets\splash_source.png"

New-Item -ItemType Directory -Force -Path (Join-Path $Root.Path "assets") | Out-Null
Add-Type -AssemblyName System.Drawing

$width = 320
$height = 200
$bitmap = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$script:graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$script:graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$script:graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$script:graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$script:graphics.Clear([System.Drawing.Color]::Black)

function New-CpcColor {
    param([int]$R, [int]$G, [int]$B)
    return [System.Drawing.Color]::FromArgb($R, $G, $B)
}

$black = New-CpcColor 0 0 0
$cyan = New-CpcColor 0 255 255
$yellow = New-CpcColor 255 255 0
$blue = New-CpcColor 0 0 255
$orange = New-CpcColor 255 128 0
$green = New-CpcColor 0 255 0
$red = New-CpcColor 255 0 0
$magenta = New-CpcColor 255 0 255
$white = New-CpcColor 255 255 255
$grey = New-CpcColor 160 160 160
$sky = New-CpcColor 0 128 255
$mauve = New-CpcColor 128 128 255

function Fill-Rect {
    param([int]$X, [int]$Y, [int]$W, [int]$H, [System.Drawing.Color]$Color)
    if ($W -le 0 -or $H -le 0) { return }
    $brush = New-Object System.Drawing.SolidBrush $Color
    $script:graphics.FillRectangle($brush, $X, $Y, $W, $H)
    $brush.Dispose()
}

function Stroke-Rect {
    param([int]$X, [int]$Y, [int]$W, [int]$H, [int]$T, [System.Drawing.Color]$Color)
    Fill-Rect $X $Y $W $T $Color
    Fill-Rect $X ($Y + $H - $T) $W $T $Color
    Fill-Rect $X $Y $T $H $Color
    Fill-Rect ($X + $W - $T) $Y $T $H $Color
}

$patterns = @{
    "A" = @("01110","10001","10001","11111","10001","10001","10001")
    "D" = @("11110","10001","10001","10001","10001","10001","11110")
    "E" = @("11111","10000","10000","11110","10000","10000","11111")
    "F" = @("11111","10000","10000","11110","10000","10000","10000")
    "I" = @("11111","00100","00100","00100","00100","00100","11111")
    "M" = @("10001","11011","10101","10101","10001","10001","10001")
    "O" = @("01110","10001","10001","10001","10001","10001","01110")
    "P" = @("11110","10001","10001","11110","10000","10000","10000")
    "R" = @("11110","10001","10001","11110","10100","10010","10001")
    "S" = @("01111","10000","10000","01110","00001","00001","11110")
    "T" = @("11111","00100","00100","00100","00100","00100","00100")
}

$smallPatterns = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)
$smallPatterns["M"] = @("10001","11011","10101","10001","10001")
$smallPatterns["a"] = @("000","011","101","111","101")
$smallPatterns["d"] = @("001","011","101","101","011")
$smallPatterns["e"] = @("010","101","111","100","011")
$smallPatterns["b"] = @("100","110","101","101","110")
$smallPatterns["y"] = @("101","101","011","001","110")
$smallPatterns["B"] = @("110","101","110","101","110")
$smallPatterns["g"] = @("011","101","011","001","110")
$smallPatterns["o"] = @("000","010","101","101","010")
$smallPatterns["n"] = @("000","110","101","101","101")
$smallPatterns["v"] = @("000","101","101","101","010")
$smallPatterns[","] = @("0","0","0","1","1")
$smallPatterns["0"] = @("111","101","101","101","111")
$smallPatterns["2"] = @("111","001","111","100","111")
$smallPatterns["6"] = @("111","100","111","101","111")

function Draw-BlockChar {
    param([string]$Char, [int]$X, [int]$Y, [int]$Scale, [System.Drawing.Color]$Color)
    if (-not $patterns.ContainsKey($Char)) { return }
    $rows = $patterns[$Char]
    for ($row = 0; $row -lt $rows.Count; $row++) {
        for ($col = 0; $col -lt 5; $col++) {
            if ($rows[$row][$col] -eq "1") {
                Fill-Rect ($X + $col * $Scale) ($Y + $row * $Scale) ($Scale - 1) ($Scale - 1) $Color
            }
        }
    }
}

function Draw-SmallChar {
    param([string]$Char, [int]$X, [int]$Y, [int]$Scale, [System.Drawing.Color]$Color)
    if (-not $smallPatterns.ContainsKey($Char)) { return 0 }
    $rows = $smallPatterns[$Char]
    $charWidth = $rows[0].Length
    for ($row = 0; $row -lt $rows.Count; $row++) {
        for ($col = 0; $col -lt $charWidth; $col++) {
            if ($rows[$row][$col] -eq "1") {
                Fill-Rect ($X + $col * $Scale) ($Y + $row * $Scale) $Scale $Scale $Color
            }
        }
    }
    return ($charWidth + 1) * $Scale
}

function Draw-SmallText {
    param([string]$Text, [int]$X, [int]$Y, [int]$Scale, [System.Drawing.Color]$Color)
    $cx = $X
    foreach ($ch in $Text.ToCharArray()) {
        if ($ch -eq " ") {
            $cx += 3 * $Scale
            continue
        }
        $advance = Draw-SmallChar ([string]$ch) $cx $Y $Scale $Color
        if ($advance -eq 0) {
            $cx += 3 * $Scale
        } else {
            $cx += $advance
        }
    }
}

function Draw-BlockText {
    param([string]$Text, [int]$X, [int]$Y, [int]$Scale, [object[]]$Colors)
    $cx = $X
    $colourIndex = 0
    foreach ($ch in $Text.ToCharArray()) {
        if ($ch -eq " ") {
            $cx += 3 * $Scale
            continue
        }
        Draw-BlockChar ([string]$ch) $cx $Y $Scale $Colors[$colourIndex % $Colors.Count]
        $cx += 6 * $Scale
        $colourIndex++
    }
}

function Draw-Tile {
    param([int]$X, [int]$Y, [int]$Size, [System.Drawing.Color]$Color)
    Fill-Rect $X $Y $Size $Size $Color
    Fill-Rect $X $Y $Size 1 $white
    Fill-Rect $X $Y 1 $Size $white
    Fill-Rect ($X + $Size - 1) $Y 1 $Size $black
    Fill-Rect $X ($Y + $Size - 1) $Size 1 $black
}

function Draw-BoardTile {
    param([int]$Col, [int]$Row, [System.Drawing.Color]$Color)
    $cell = 8
    $x = 42 + $Col * $cell
    $y = 78 + $Row * $cell
    Fill-Rect $x $y 7 7 $Color
}

Fill-Rect 0 0 $width $height $black
Fill-Rect 0 0 $width 4 $black
Fill-Rect 0 196 $width 4 $black
Fill-Rect 0 0 4 $height $black
Fill-Rect 316 0 4 $height $black

Draw-BlockText "TETRIS" 37 8 7 @($cyan, $yellow, $blue, $orange, $green, $red)
Draw-SmallText "Made by Bgonev, 2026" 82 60 2 $grey

$boardX = 38
$boardY = 74
$boardW = 88
$boardH = 104
Stroke-Rect $boardX $boardY $boardW $boardH 4 $grey
Fill-Rect 42 78 80 96 $black

$stack = @(
    @(0,11,$cyan), @(1,11,$cyan), @(2,11,$cyan), @(3,11,$cyan), @(6,11,$orange), @(7,11,$orange), @(8,11,$orange),
    @(0,10,$green), @(1,10,$green), @(4,10,$yellow), @(5,10,$yellow), @(6,10,$orange), @(9,10,$red),
    @(1,9,$green), @(2,9,$green), @(4,9,$yellow), @(5,9,$yellow), @(7,9,$magenta), @(8,9,$magenta), @(9,9,$red),
    @(3,8,$blue), @(4,8,$blue), @(5,8,$blue), @(5,7,$blue), @(8,8,$magenta), @(9,8,$magenta)
)
foreach ($tile in $stack) {
    Draw-BoardTile $tile[0] $tile[1] $tile[2]
}
Draw-BoardTile 4 2 $magenta
Draw-BoardTile 3 3 $magenta
Draw-BoardTile 4 3 $magenta
Draw-BoardTile 5 3 $magenta

Draw-Tile 186 80 18 $cyan
Draw-Tile 204 80 18 $cyan
Draw-Tile 222 80 18 $cyan
Draw-Tile 240 80 18 $cyan

Draw-Tile 188 126 18 $yellow
Draw-Tile 206 126 18 $yellow
Draw-Tile 188 144 18 $yellow
Draw-Tile 206 144 18 $yellow

Draw-Tile 246 126 18 $red
Draw-Tile 264 126 18 $red
Draw-Tile 228 144 18 $red
Draw-Tile 246 144 18 $red

Draw-BlockText "PRESS FIRE" 86 174 3 @($white)

$bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$script:graphics.Dispose()
$bitmap.Dispose()

Write-Host "Generated $OutPath"
