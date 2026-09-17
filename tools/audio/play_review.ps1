param([string]$Godot = 'C:/Users/ysyki/Godot/Godot_console.exe')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
& $Godot --path $projectPath --disable-crash-handler --log-file "$projectPath/docs/audio/review/play.log" --script res://tools/audio/review.gd
if ($LASTEXITCODE -ne 0) { throw 'Sound review failed; see docs/audio/review/play.log' }
