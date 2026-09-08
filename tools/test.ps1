param([string]$Godot = 'C:/Users/ysyki/Godot/Godot_console.exe')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $projectPath 'docs/validation'
New-Item -ItemType Directory -Force $logPath | Out-Null
$results = @()
foreach ($test in Get-ChildItem -LiteralPath (Join-Path $projectPath 'tests') -Filter '*_test.gd' | Sort-Object Name) {
    $logFile = Join-Path $logPath ($test.BaseName + '.log')
    $arguments = @('--path', ('"' + $projectPath + '"'), '--disable-crash-handler', '--log-file', ('"' + $logFile + '"'), '--script', "res://tests/$($test.Name)")
    # The game deliberately disables playback when DisplayServer is headless.
    if ($test.Name -notin @('audio_test.gd', 'view_state_test.gd', 'depth_view_test.gd', 'sniper_warning_test.gd')) { $arguments += '--headless' }
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(120000)) {
        $process.Kill()
        throw "Test timed out: $($test.Name); see $logFile"
    }
    $process.Refresh()
    $exitCode = $process.ExitCode
    $log = Get-Content -LiteralPath $logFile -Raw
    $completion = switch ($test.Name) {
        'halo_shock_test.gd' { 'LV45 SHOCK:' }
        'title_exit_test.gd' { 'Native title Esc dispatched' }
        default { 'PASS:' }
    }
    $passed = $exitCode -eq 0 -and $log -match $completion -and $log -notmatch 'FAIL:|SCRIPT ERROR:|ERROR:'
    $results += [pscustomobject]@{ Test = $test.Name; Passed = $passed; ExitCode = $exitCode }
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logPath 'tests.json')
$results | Format-Table
if ($results.Passed -contains $false) { throw 'Regression checks failed; see docs/validation.' }
