# Führt alle Tests aus: erst die schnellen Tests (test/), dann jeden App-Test
# (integration_test/) einzeln – mehrere in einem Lauf scheitern unter Windows.
#
# Startet den Demo-Server, falls er nicht läuft (und beendet ihn danach wieder).
# Ein App-Test, der schon beim Start scheitert (bekannter Flutter-Schluckauf),
# wird einmal wiederholt.
#
# Start:  powershell -ExecutionPolicy Bypass -File tool/run_all_tests.ps1
#         ... -File tool/run_all_tests.ps1 -Only roulette,quiz   (nur bestimmte App-Tests)

param([string[]]$Only = @())

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$flutter = Join-Path $env:USERPROFILE 'dev\flutter\bin\flutter.bat'
$dart = Join-Path $env:USERPROFILE 'dev\flutter\bin\dart.bat'

function Test-Port8097 { [bool](Get-NetTCPConnection -LocalPort 8097 -State Listen -ErrorAction SilentlyContinue) }

$startedServer = $null
if (-not (Test-Port8097)) {
    Write-Host 'Starte Demo-Server ...'
    $startedServer = Start-Process -FilePath $dart -ArgumentList 'run', 'tool/mock_server.dart' -PassThru -WindowStyle Hidden
    for ($i = 0; $i -lt 60 -and -not (Test-Port8097); $i++) { Start-Sleep -Milliseconds 500 }
}

$results = [System.Collections.Generic.List[object]]::new()

function Invoke-TestRun([string]$name, [string[]]$arguments) {
    $out = & $flutter @arguments 2>&1 | Out-String
    $passed = $out -match 'All tests passed'
    $summary = ($out -split "`n" | Where-Object { $_ -match 'All tests passed|Some tests failed|Expected:|Actual:' } | Select-Object -Last 3) -join ' | '
    return [pscustomobject]@{ Test = $name; Ok = $passed; Info = $summary.Trim(); Output = $out }
}

Write-Host '== Schnelle Tests (test/)'
$r = Invoke-TestRun 'unit' @('test')
$results.Add($r)

$files = Get-ChildItem integration_test -Filter '*_test.dart' | Sort-Object Name
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
if ($Only.Count -gt 0) { $files = $files | Where-Object { $n = $_.BaseName -replace '_test$', ''; $Only -contains $n } }
foreach ($f in $files) {
    Write-Host "== $($f.Name)"
    $r = Invoke-TestRun $f.BaseName @('test', "integration_test/$($f.Name)", '-d', 'windows')
    if (-not $r.Ok -and $r.Info -match '\+0: Some tests failed|00:00 \+0') {
        Write-Host '   (Startfehler - wiederhole einmal)'
        $r = Invoke-TestRun $f.BaseName @('test', "integration_test/$($f.Name)", '-d', 'windows')
    }
    $results.Add($r)
}

if ($startedServer) { Stop-Process -Id $startedServer.Id -Force -ErrorAction SilentlyContinue
    Get-NetTCPConnection -LocalPort 8097 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue } }

Write-Host ''
Write-Host '==================== Ergebnis ===================='
foreach ($r in $results) {
    $mark = if ($r.Ok) { 'OK    ' } else { 'FEHLER' }
    Write-Host ("{0}  {1,-22} {2}" -f $mark, $r.Test, $(if ($r.Ok) { '' } else { $r.Info }))
}
$failed = @($results | Where-Object { -not $_.Ok })
Write-Host ("{0} von {1} bestanden" -f ($results.Count - $failed.Count), $results.Count)
if ($failed.Count -gt 0) {
    $log = Join-Path $root 'build\test_failures.log'
    New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
    ($failed | ForEach-Object { "##### $($_.Test)`n$($_.Output)" }) -join "`n" | Out-File -Encoding utf8 $log
    Write-Host "Details: $log"
    exit 1
}
