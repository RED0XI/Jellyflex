# Erzeugt das App-Icon (windows/runner/resources/app_icon.ico) und ein PNG (assets/icon.png).
# Start:  powershell -ExecutionPolicy Bypass -File tool/make_icon.ps1
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent

function New-IconBitmap([int]$size) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.Clear([System.Drawing.Color]::Transparent)

  # Abgerundetes Quadrat mit Verlauf (Akzentfarben der App).
  $r = [single]($size * 0.22)
  $rect = New-Object System.Drawing.RectangleF 0, 0, $size, $size
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc(0, 0, 2 * $r, 2 * $r, 180, 90)
  $path.AddArc($size - 2 * $r, 0, 2 * $r, 2 * $r, 270, 90)
  $path.AddArc($size - 2 * $r, $size - 2 * $r, 2 * $r, 2 * $r, 0, 90)
  $path.AddArc(0, $size - 2 * $r, 2 * $r, 2 * $r, 90, 90)
  $path.CloseFigure()
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(255, 139, 92, 246)), ([System.Drawing.Color]::FromArgb(255, 0, 164, 220)), 45
  $g.FillPath($brush, $path)

  # Abgerundetes Play-Dreieck.
  $cx = $size * 0.54; $cy = $size * 0.5; $h = $size * 0.40
  $p1 = New-Object System.Drawing.PointF ([single]($cx - $h * 0.45)), ([single]($cy - $h * 0.5))
  $p2 = New-Object System.Drawing.PointF ([single]($cx + $h * 0.55)), ([single]$cy)
  $p3 = New-Object System.Drawing.PointF ([single]($cx - $h * 0.45)), ([single]($cy + $h * 0.5))
  $tri = New-Object System.Drawing.Drawing2D.GraphicsPath
  $tri.AddPolygon(@($p1, $p2, $p3))
  $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ([single]([Math]::Max(1, $size * 0.06)))
  $pen.LineJoin = 'Round'
  $g.FillPath($white, $tri)
  $g.DrawPath($pen, $tri)

  $g.Dispose()
  return $bmp
}

function Get-PngBytes($bmp) {
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  return , $ms.ToArray()
}

# PNG für die App selbst.
$assets = Join-Path $root 'assets'
New-Item -ItemType Directory -Force $assets | Out-Null
$big = New-IconBitmap 512
$big.Save((Join-Path $assets 'icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)

# ICO mit mehreren Größen (PNG-komprimierte Einträge).
$sizes = 16, 24, 32, 48, 64, 128, 256
$images = foreach ($s in $sizes) { , (Get-PngBytes (New-IconBitmap $s)) }
$out = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter $out
$w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $s = $sizes[$i]; $len = $images[$i].Length
  $w.Write([byte]($(if ($s -ge 256) { 0 } else { $s })))
  $w.Write([byte]($(if ($s -ge 256) { 0 } else { $s })))
  $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([UInt16]1); $w.Write([UInt16]32)
  $w.Write([UInt32]$len); $w.Write([UInt32]$offset)
  $offset += $len
}
foreach ($img in $images) { $w.Write($img) }
$w.Flush()
$ico = Join-Path $root 'windows\runner\resources\app_icon.ico'
[System.IO.File]::WriteAllBytes($ico, $out.ToArray())
"Icon geschrieben: $ico"
