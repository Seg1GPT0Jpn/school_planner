# Usage:
#   powershell -ExecutionPolicy Bypass -File release_web.ps1 "release notes"
# Ver.2/Ver.3 の Web 版を Firebase Hosting に公開する
param(
  [string]$Notes = "update"
)

# 1. Tests
flutter test
if ($LASTEXITCODE -ne 0) { Write-Host "Tests failed. Stopped." -ForegroundColor Red; exit 1 }

# 2. Build number +1（Pixel版と同じカウンタを共有）
$text = Get-Content pubspec.yaml -Raw -Encoding UTF8
$m = [regex]::Match($text, 'version:\s*([\d\.]+)\+(\d+)')
$build = [int]$m.Groups[2].Value + 1
$text = $text -replace 'version:\s*[\d\.]+\+\d+', ("version: " + $m.Groups[1].Value + "+" + $build)
[IO.File]::WriteAllText("$PWD\pubspec.yaml", $text, (New-Object Text.UTF8Encoding $false))
Write-Host "Build number: $build"

# 3. Build（Web版）
flutter build web --release
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed." -ForegroundColor Red; exit 1 }

# 4. Firebase Hosting へデプロイ
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { Write-Host "Deploy failed." -ForegroundColor Red; exit 1 }

# 5. Save to git
git add .
git commit -m "web release +$build : $Notes"

Write-Host "Done! https://school-planner-30628.web.app" -ForegroundColor Green
