# WrestlingHub Italia - genera le copertine grafiche (1200x630) per guide e schede evento.
# Usate quando un articolo non ha una foto con licenza libera, e come anteprima per i social.
# Solo Windows (usa System.Drawing e il font Oswald installato). Le copertine vanno poi caricate su GitHub.
# Uso:  powershell -File genera-copertine.ps1          (crea solo le copertine mancanti)
#       powershell -File genera-copertine.ps1 -Tutte   (le rigenera tutte)

param([switch]$Tutte)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)
$outDir = Join-Path $root 'assets/img/copertine'
New-Item -ItemType Directory -Force $outDir | Out-Null

$W = 1200; $H = 630
$gold = [Drawing.Color]::FromArgb(245, 183, 0)
$accentBy = @{
  'WWE' = [Drawing.Color]::FromArgb(225, 6, 0); 'AEW' = [Drawing.Color]::FromArgb(201, 162, 39)
  'TNA' = [Drawing.Color]::FromArgb(43, 123, 255); 'NJPW' = [Drawing.Color]::FromArgb(255, 77, 109)
  'Classifiche ed elenchi' = $gold; 'Per chi inizia' = [Drawing.Color]::FromArgb(46, 196, 182)
}
$red = [Drawing.Color]::FromArgb(225, 6, 0)

function Read-Header($file) {
  $raw = [IO.File]::ReadAllText($file, $utf8)
  $meta = @{ file = [IO.Path]::GetFileNameWithoutExtension($file) }
  if ($raw -match '(?s)^\s*<!--(.*?)-->') {
    foreach ($line in ($Matches[1] -split "`n")) { if ($line -match '^\s*([a-z]+)\s*:\s*(.+?)\s*$') { $meta[$Matches[1]] = $Matches[2] } }
  }
  if (-not $meta.slug) { $meta.slug = $meta.file }
  return $meta
}

# spezza il titolo in righe che stanno nella larghezza indicata
function Wrap-Text($g, [string]$text, $font, [int]$maxWidth) {
  $lines = @(); $cur = ''
  foreach ($word in ($text -split '\s+')) {
    $try = if ($cur) { "$cur $word" } else { $word }
    if ($g.MeasureString($try, $font).Width -le $maxWidth -or -not $cur) { $cur = $try } else { $lines += $cur; $cur = $word }
  }
  if ($cur) { $lines += $cur }
  return ,$lines
}

function New-Cover([string]$path, [string]$kicker, [string]$title, $accent) {
  $bmp = New-Object Drawing.Bitmap $W, $H
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.InterpolationMode = 'HighQualityBicubic'

  # sfondo: nero con un alone del colore d'accento in basso a destra
  $g.Clear([Drawing.Color]::FromArgb(13, 13, 16))
  $glow = New-Object Drawing.Drawing2D.GraphicsPath
  $glow.AddEllipse(520, 180, 1100, 800)
  $pgb = New-Object Drawing.Drawing2D.PathGradientBrush $glow
  $pgb.CenterColor = [Drawing.Color]::FromArgb(150, $accent)
  $pgb.SurroundColors = @([Drawing.Color]::FromArgb(0, $accent))
  $g.FillPath($pgb, $glow)
  # diagonali decorative
  $stripe = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(18, 255, 255, 255))
  foreach ($x in 820, 900, 980) { $g.FillPolygon($stripe, [Drawing.Point[]]@((New-Object Drawing.Point $x, 0), (New-Object Drawing.Point ($x + 40), 0), (New-Object Drawing.Point ($x - 260), $H), (New-Object Drawing.Point ($x - 300), $H))) }
  # barra laterale
  $g.FillRectangle((New-Object Drawing.SolidBrush $accent), 0, 0, 16, $H)

  # marchio in alto a destra
  $brandFont = New-Object Drawing.Font('Oswald', 26, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
  $wA = $g.MeasureString('WRESTLING', $brandFont).Width; $wB = $g.MeasureString('HUB', $brandFont).Width; $wC = $g.MeasureString('ITALIA', $brandFont).Width
  $bx = $W - 70 - ($wA + $wB + $wC - 12)
  $g.DrawString('WRESTLING', $brandFont, [Drawing.Brushes]::White, $bx, 56)
  $g.DrawString('HUB', $brandFont, (New-Object Drawing.SolidBrush $red), $bx + $wA - 6, 56)
  $g.DrawString('ITALIA', $brandFont, (New-Object Drawing.SolidBrush $gold), $bx + $wA + $wB - 12, 56)

  # categoria
  $kFont = New-Object Drawing.Font('Oswald', 30, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
  $g.DrawString($kicker.ToUpper(), $kFont, (New-Object Drawing.SolidBrush $gold), 72, 56)

  # titolo: dimensione automatica finché non sta in 4 righe
  $size = 86; $maxW = 1040
  do {
    $tFont = New-Object Drawing.Font('Oswald', $size, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $lines = Wrap-Text $g $title.ToUpper() $tFont $maxW
    $lineH = $size * 1.12
    $size -= 4
  } while (($lines.Count -gt 4 -or ($lines.Count * $lineH) -gt 380) -and $size -gt 40)
  $y = 140 + (380 - $lines.Count * $lineH) / 2
  $shadow = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(120, 0, 0, 0))
  foreach ($l in $lines) { $g.DrawString($l, $tFont, $shadow, 75, $y + 3); $g.DrawString($l, $tFont, [Drawing.Brushes]::White, 72, $y); $y += $lineH }

  # piede
  $g.FillRectangle((New-Object Drawing.SolidBrush $accent), 72, 548, 120, 6)
  $fFont = New-Object Drawing.Font('Segoe UI', 24, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
  $g.DrawString('wrestlinghubitalia.com', $fFont, (New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(200, 200, 205))), 210, 533)

  # salva in JPEG (qualità 88)
  $enc = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | ? MimeType -eq 'image/jpeg'
  $ep = New-Object Drawing.Imaging.EncoderParameters 1
  $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), 88L
  $bmp.Save($path, $enc, $ep)
  $g.Dispose(); $bmp.Dispose()
}

$events = @{}
$evJson = [IO.File]::ReadAllText((Join-Path $root 'data/events.json'), $utf8) | ConvertFrom-Json
foreach ($e in $evJson.events) { $events[$e.id] = $e }

$made = 0
foreach ($f in (Get-ChildItem (Join-Path $root 'contenuti/guide') -Filter *.html)) {
  $m = Read-Header $f.FullName; $out = Join-Path $outDir "$($m.slug).jpg"
  if ((Test-Path $out) -and -not $Tutte) { continue }
  $accent = if ($accentBy[$m.section]) { $accentBy[$m.section] } else { $red }
  New-Cover $out $m.kicker $m.title $accent; $made++
}
foreach ($f in (Get-ChildItem (Join-Path $root 'contenuti/eventi') -Filter *.html)) {
  $m = Read-Header $f.FullName; $ev = $events[$m.file]; if (-not $ev) { continue }
  $out = Join-Path $outDir "$($m.file).jpg"
  if ((Test-Path $out) -and -not $Tutte) { continue }
  $d = [datetime]::ParseExact($ev.date, 'yyyy-MM-dd', $null).ToString('d MMMM yyyy', [Globalization.CultureInfo]'it-IT')
  $kick = "$($ev.promotion) " + [char]0x00B7 + " $d"   # punto medio scritto come codice: lo script resta solo ASCII
  $accent = if ($accentBy[$ev.promotion]) { $accentBy[$ev.promotion] } else { $red }
  New-Cover $out $kick $ev.name $accent; $made++
}
"Copertine create: $made (cartella assets/img/copertine)"
