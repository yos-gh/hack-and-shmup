param([string]$Godot = 'C:/Users/ysyki/Godot/Godot_console.exe')
$projectPath = Split-Path -Parent $PSScriptRoot
& $Godot --headless --path $projectPath --disable-crash-handler --log-file "$projectPath/export.log" --export-release Web "$projectPath/web/game-v2.html"
if ($LASTEXITCODE -ne 0) { throw 'Web export failed' }
# web/index.html is the hand-authored landing page embedding game-v2.html.
