param([string]$Godot = 'C:/Users/ysyki/Godot/Godot_console.exe')
$projectPath = Split-Path -Parent $PSScriptRoot
& $Godot --headless --path $projectPath --disable-crash-handler --log-file "$projectPath/export.log" --export-release Web "$projectPath/web/game-v2.html"
if ($LASTEXITCODE -ne 0) { throw 'Web export failed' }
# web/index.html is the hand-authored landing page embedding game-v2.html.

$fontOutput = Join-Path $projectPath 'web/fonts'
New-Item -ItemType Directory -Force -Path $fontOutput | Out-Null
foreach ($font in @('Barlow-Regular.ttf','Rajdhani-SemiBold.ttf','Barlow-OFL.txt','Rajdhani-OFL.txt')) {
    Copy-Item -LiteralPath (Join-Path $projectPath "assets/fonts/$font") -Destination $fontOutput
}
& $Godot --headless --path $projectPath --disable-crash-handler --log-file "$projectPath/notices-export.log" --script res://tools/export_notices.gd -- "$projectPath/web/THIRD_PARTY_NOTICES.txt"
if ($LASTEXITCODE -ne 0) { throw 'Notice export failed' }
