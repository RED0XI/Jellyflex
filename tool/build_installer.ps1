# Baut die Release-Version und daraus den Installer dist\Jellyflex-Setup-<Version>.exe.
# Start:  powershell -ExecutionPolicy Bypass -File tool/build_installer.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

# Version aus pubspec.yaml (z. B. "0.2.0+2" → "0.2.0").
$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
Write-Host "Baue Jellyflex $version ..."

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) { $env:Path += ";$env:USERPROFILE\dev\flutter\bin" }
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Flutter-Build fehlgeschlagen' }

$iscc = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup nicht gefunden (winget install JRSoftware.InnoSetup --scope user)' }

& $iscc "/DAppVersion=$version" /Q "installer\jellyflex.iss"
if ($LASTEXITCODE -ne 0) { throw 'Installer-Build fehlgeschlagen' }
Write-Host "Fertig: dist\Jellyflex-Setup-$version.exe"
