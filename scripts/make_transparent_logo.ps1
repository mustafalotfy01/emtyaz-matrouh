Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\FUJITSU\.gemini\antigravity\brain\dc03c6e2-7da9-407e-a932-54164cade876\.user_uploaded\media_1787046716725.jpg"
$baseDir = "d:\Mostafa\Nurse matrouh"

if (!(Test-Path $srcPath)) {
    Write-Error "Source logo file not found at: $srcPath"
    exit 1
}

$srcImg = [System.Drawing.Bitmap]::FromFile($srcPath)
$width = $srcImg.Width
$height = $srcImg.Height

Write-Host "Processing logo transparency for image size: $width x $height" -ForegroundColor Cyan

# Create 32-bit ARGB bitmap for transparency
$transparentBmp = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

# Lock bits for fast pixel processing
$rect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
$srcData = $srcImg.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$destData = $transparentBmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

$bytes = [Math]::Abs($srcData.Stride) * $height
$rgbValues = New-Object byte[] $bytes
$destValues = New-Object byte[] $bytes

[System.Runtime.InteropServices.Marshal]::Copy($srcData.Scan0, $rgbValues, 0, $bytes)

# Process pixels: Format32bppArgb has 4 bytes per pixel (B, G, R, A)
for ($i = 0; $i -lt $bytes; $i += 4) {
    $b = $rgbValues[$i]
    $g = $rgbValues[$i + 1]
    $r = $rgbValues[$i + 2]

    # Calculate brightness / max channel
    $maxVal = [Math]::Max($r, [Math]::Max($g, $b))

    # Black threshold with smooth alpha edge transition
    # Values <= 12 are fully transparent (0 alpha)
    # Values between 12 and 35 smoothly ramp alpha from 0 to 255
    # Values > 35 are fully opaque
    if ($maxVal -le 10) {
        $destValues[$i] = 0
        $destValues[$i + 1] = 0
        $destValues[$i + 2] = 0
        $destValues[$i + 3] = 0 # Fully transparent
    } elseif ($maxVal -lt 30) {
        $alpha = [byte]((($maxVal - 10) / 20.0) * 255.0)
        $destValues[$i] = $b
        $destValues[$i + 1] = $g
        $destValues[$i + 2] = $r
        $destValues[$i + 3] = $alpha
    } else {
        $destValues[$i] = $b
        $destValues[$i + 1] = $g
        $destValues[$i + 2] = $r
        $destValues[$i + 3] = 255 # Opaque
    }
}

[System.Runtime.InteropServices.Marshal]::Copy($destValues, 0, $destData.Scan0, $bytes)

$srcImg.UnlockBits($srcData)
$transparentBmp.UnlockBits($destData)
$srcImg.Dispose()

Write-Host "Transparent bitmap created in memory. Resizing to target asset dimensions..." -ForegroundColor Cyan

function Resize-And-Save-Bmp([System.Drawing.Bitmap]$sourceBmp, [string]$targetPath, [int]$w, [int]$h) {
    $parent = Split-Path -Parent $targetPath
    if (!(Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $destBmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($destBmp)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $graphics.DrawImage($sourceBmp, 0, 0, $w, $h)
    $graphics.Dispose()

    if (Test-Path $targetPath) {
        Remove-Item -Path $targetPath -Force
    }

    $destBmp.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host "Generated transparent asset: $targetPath ($w x $h)"
}

# 1. Main In-App Logo
Resize-And-Save-Bmp $transparentBmp "$baseDir\assets\images\logo.png" 1024 1024

# 2. Web Favicon & PWA Icons
Resize-And-Save-Bmp $transparentBmp "$baseDir\web\favicon.png" 128 128
Resize-And-Save-Bmp $transparentBmp "$baseDir\web\icons\Icon-192.png" 192 192
Resize-And-Save-Bmp $transparentBmp "$baseDir\web\icons\Icon-512.png" 512 512
Resize-And-Save-Bmp $transparentBmp "$baseDir\web\icons\Icon-maskable-192.png" 192 192
Resize-And-Save-Bmp $transparentBmp "$baseDir\web\icons\Icon-maskable-512.png" 512 512

# 3. Android Launcher Mipmaps
Resize-And-Save-Bmp $transparentBmp "$baseDir\android\app\src\main\res\mipmap-mdpi\ic_launcher.png" 48 48
Resize-And-Save-Bmp $transparentBmp "$baseDir\android\app\src\main\res\mipmap-hdpi\ic_launcher.png" 72 72
Resize-And-Save-Bmp $transparentBmp "$baseDir\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png" 96 96
Resize-And-Save-Bmp $transparentBmp "$baseDir\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png" 144 144
Resize-And-Save-Bmp $transparentBmp "$baseDir\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" 192 192

# 4. iOS AppIcon Set
$iosDir = "$baseDir\ios\Runner\Assets.xcassets\AppIcon.appiconset"
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-1024x1024@1x.png" 1024 1024
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-20x20@1x.png" 20 20
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-20x20@2x.png" 40 40
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-20x20@3x.png" 60 60
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-29x29@1x.png" 29 29
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-29x29@2x.png" 58 58
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-29x29@3x.png" 87 87
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-40x40@1x.png" 40 40
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-40x40@2x.png" 80 80
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-40x40@3x.png" 120 120
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-60x60@2x.png" 120 120
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-60x60@3x.png" 180 180
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-76x76@1x.png" 76 76
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-76x76@2x.png" 152 152
Resize-And-Save-Bmp $transparentBmp "$iosDir\Icon-App-83.5x83.5@2x.png" 167 167

$transparentBmp.Dispose()
Write-Host "Successfully converted logo to transparent PNG and regenerated all icons!" -ForegroundColor Green
