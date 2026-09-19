# Usage: powershell -ExecutionPolicy Bypass -File release.ps1 "release notes"
param([string]$Notes = "update")

$AppId  = "'1:1033493674765:android:3ed9943894669d5db64e44'"
$Tester = "kzmsegawa@gmail.com"

# 1. Tests
flutter test
if ($LASTEXITCODE -ne 0) { Write-Host "Tests failed. Stopped." -ForegroundColor Red; exit 1 }

# 2. Build number +1  (version: 1.0.0+5 -> 1.0.0+6)
$text = Get-Content pubspec.yaml -Raw -Encoding UTF8
$m = [regex]::Match($text, 'version:\s*([\d\.]+)\+(\d+)')
$build = [int]$m.Groups[2].Value + 1
$text = $text -replace 'version:\s*[\d\.]+\+\d+', ("version: " + $m.Groups[1].Value + "+" + $build)
[IO.File]::WriteAllText("$PWD\pubspec.yaml", $text, (New-Object Text.UTF8Encoding $false))
Write-Host "Build number: $build"

# 3. Build
flutter build apk --release
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed." -ForegroundColor Red; exit 1 }

# 4. Distribute
firebase appdistribution:distribute build\app\outputs\flutter-apk\app-release.apk --app $AppId --testers $Tester --release-notes $Notes
if ($LASTEXITCODE -ne 0) { Write-Host "Upload failed." -ForegroundColor Red; exit 1 }

# 5. Save to git
git add .
git commit -m "release +$build : $Notes"
Write-Host "Done! Check App Tester on your phone." -ForegroundColor Green