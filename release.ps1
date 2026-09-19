# Usage:
#   powershell -ExecutionPolicy Bypass -File release.ps1 192.168.1.5:41234 "release notes"
#   (address = the one shown at the top of Pixel's Wireless debugging screen)
param(
  [Parameter(Mandatory = $true)][string]$Addr,
  [string]$Notes = "update"
)

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$apk = "build\app\outputs\flutter-apk\app-release.apk"

# 1. Connect to Pixel over Wi-Fi
& $adb connect $Addr
if (-not ((& $adb devices) -match [regex]::Escape($Addr))) {
  Write-Host "Pixel not found. Turn on Wireless debugging and check the address." -ForegroundColor Red
  exit 1
}

# 2. Tests
flutter test
if ($LASTEXITCODE -ne 0) { Write-Host "Tests failed. Stopped." -ForegroundColor Red; exit 1 }

# 3. Build number +1
$text = Get-Content pubspec.yaml -Raw -Encoding UTF8
$m = [regex]::Match($text, 'version:\s*([\d\.]+)\+(\d+)')
$build = [int]$m.Groups[2].Value + 1
$text = $text -replace 'version:\s*[\d\.]+\+\d+', ("version: " + $m.Groups[1].Value + "+" + $build)
[IO.File]::WriteAllText("$PWD\pubspec.yaml", $text, (New-Object Text.UTF8Encoding $false))
Write-Host "Build number: $build"

# 4. Build
flutter build apk --release
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed." -ForegroundColor Red; exit 1 }

# 5. Install (keeps app data)
& $adb -s $Addr install -r $apk
if ($LASTEXITCODE -ne 0) { Write-Host "Install failed." -ForegroundColor Red; exit 1 }

# 6. Save to git
git add .
git commit -m "release +$build : $Notes"
Write-Host "Done! Open the app on your Pixel." -ForegroundColor Green