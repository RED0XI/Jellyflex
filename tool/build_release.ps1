# Baut den Installer fuer eine Veroeffentlichung in einem neutralen Ordner
# (C:\JellyflexBuild, ausserhalb des Benutzerordners) - sonst landet ein Pfad mit dem
# Windows-Benutzernamen im Programm (Dart schreibt "file:///C:/Users/<Name>/..." in data\app.so).
# Start:  powershell -ExecutionPolicy Bypass -File tool/build_release.ps1 [-Ref v0.3.0]
param([string]$Ref = 'HEAD')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = 'C:\JellyflexBuild'
Set-Location $root
if (Test-Path $build) { git worktree remove --force $build }
git worktree add --detach $build $Ref
if ($LASTEXITCODE -ne 0) { throw 'Arbeitskopie konnte nicht angelegt werden' }
try {
  & "$build\tool\build_installer.ps1"
  if ($LASTEXITCODE -ne 0) { throw 'Installer-Build fehlgeschlagen' }
  # Gegenprobe: in keiner Programmdatei der Benutzername (ASCII und UTF-16).
  $needles = @($env:USERNAME)
  foreach ($file in Get-ChildItem "$build\build\windows\x64\runner\Release" -Recurse -File) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
    $wide = [System.Text.Encoding]::Unicode.GetString($bytes)
    foreach ($n in $needles) {
      if ($ascii.Contains($n) -or $wide.Contains($n)) {
        throw "'$n' in $($file.Name) gefunden - nicht veroeffentlichen!"
      }
    }
  }
  New-Item -ItemType Directory -Force "$root\dist" | Out-Null
  Copy-Item "$build\dist\*" "$root\dist\" -Force
  Write-Host 'Kein Benutzerpfad im Programm. Installer liegt in dist\.'
} finally {
  Set-Location $root
  git worktree remove --force $build
}
