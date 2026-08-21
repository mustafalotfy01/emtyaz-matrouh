Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\FUJITSU\.gemini\antigravity\brain\dc03c6e2-7da9-407e-a932-54164cade876\.user_uploaded\media_1787046716725.jpg"
$baseDir = "d:\Mostafa\Nurse matrouh"

if (!(Test-Path $srcPath)) {
    Write-Error "Source logo file not found at: $srcPath"
    exit 1
}

$srcImg = [System.Drawing.Image]::FromFile($srcPath)

function Resize-And-Save([string]$targetPath, [int]$width, [int]$height) {
    $parent = Split-Path -Parent $targetPath
    if (!(Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $destBmp = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($destBmp)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $graphics.DrawImage($srcImg, 0, 0, $width, $height)
    $graphics.Dispose()

    if (Test-Path $targetPath) {
        Remove-Item -Path $targetPath -Force
    }

    $destBmp.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host "Generated: $targetPath ($width x $height)"
}

Write-Host "Generating new high-res logo and application launcher icons..." -ForegroundColor Cyan

# 1. Main Application Asset Logo
Resize-And-Save "$baseDir\assets\images\logo.png" 1024 1024

# 2. Web Favicon & PWA Icons
Resize-And-Save "$baseDir\web\favicon.png" 128 128
Resize-And-Save "$baseDir\web\icons\Icon-192.png" 192 192
Resize-And-Save "$baseDir\web\icons\Icon-512.png" 512 512
Resize-And-Save "$baseDir\web\icons\Icon-maskable-192.png" 192 192
Resize-And-Save "$baseDir\web\icons\Icon-maskable-512.png" 512 512

# 3. Android Launcher Mipmaps
Resize-And-Save "$baseDir\android\app\src\main\res\mipmap-mdpi\ic_launcher.png" 48 48
Resize-And-Save "$baseDir\android\app\src\main\res\mipmap-hdpi\ic_launcher.png" 72 72
Resize-And-Save "$baseDir\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png" 96 96
Resize-And-Save "$baseDir\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png" 144 144
Resize-And-Save "$baseDir\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" 192 192

# 4. iOS AppIcon Set
$iosDir = "$baseDir\ios\Runner\Assets.xcassets\AppIcon.appiconset"
Resize-And-Save "$iosDir\Icon-App-1024x1024@1x.png" 1024 1024
Resize-And-Save "$iosDir\Icon-App-20x20@1x.png" 20 20
Resize-And-Save "$iosDir\Icon-App-20x20@2x.png" 40 40
Resize-And-Save "$iosDir\Icon-App-20x20@3x.png" 60 60
Resize-And-Save "$iosDir\Icon-App-29x29@1x.png" 29 29
Resize-And-Save "$iosDir\Icon-App-29x29@2x.png" 58 58
Resize-And-Save "$iosDir\Icon-App-29x29@3x.png" 87 87
Resize-And-Save "$iosDir\Icon-App-40x40@1x.png" 40 40
Resize-And-Save "$iosDir\Icon-App-40x40@2x.png" 80 80
Resize-And-Save "$iosDir\Icon-App-40x40@3x.png" 120 120
Resize-And-Save "$iosDir\Icon-App-60x60@2x.png" 120 120
Resize-And-Save "$iosDir\Icon-App-60x60@3x.png" 180 180
Resize-And-Save "$iosDir\Icon-App-76x76@1x.png" 76 76
Resize-And-Save "$iosDir\Icon-App-76x76@2x.png" 152 152
Resize-And-Save "$iosDir\Icon-App-83.5x83.5@2x.png" 167 167

# 5. iOS Launch Image Set
$launchDir = "$baseDir\ios\Runner\Assets.xcassets\LaunchImage.imageset"
Resize-And-Save "$launchDir\LaunchImage.png" 640 1136
Resize-And-Save "$launchDir\LaunchImage@2x.png" 1242 2208
Resize-And-Save "$launchDir\LaunchImage@3x.png" 1242 2688

# 6. macOS AppIcon Set
$macDir = "$baseDir\macos\Runner\Assets.xcassets\AppIcon.appiconset"
Resize-And-Save "$macDir\app_icon_16.png" 16 16
Resize-And-Save "$macDir\app_icon_32.png" 32 32
Resize-And-Save "$macDir\app_icon_64.png" 64 64
Resize-And-Save "$macDir\app_icon_128.png" 128 128
Resize-And-Save "$macDir\app_icon_256.png" 256 256
Resize-And-Save "$macDir\app_icon_512.png" 512 512
Resize-And-Save "$macDir\app_icon_1024.png" 1024 1024

$srcImg.Dispose()
Write-Host "All logo and icon assets successfully generated and replaced!" -ForegroundColor Green
