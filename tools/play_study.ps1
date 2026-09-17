param(
    [ValidateSet('normal11', 'normal19', 'siege5', 'hunter15', 'halo45')][string]$Scenario = 'normal19',
    [ValidateRange(0, 2)][int]$Weapon = 1,
    [ValidateRange(0,40)][double]$Tilt = 25,
    [int]$Seed = 19045,
    [string]$Godot = 'C:/Users/ysyki/Godot/Godot_console.exe'
)
$projectPath = Split-Path -Parent $PSScriptRoot
& $Godot --path $projectPath --disable-crash-handler --log-file "$projectPath/study.log" --script res://tools/scenario.gd -- "--scenario=$Scenario" "--seed=$Seed" "--weapon=$Weapon" --frames=0 --view=3d "--tilt=$($Tilt.ToString([System.Globalization.CultureInfo]::InvariantCulture))"
if ($LASTEXITCODE -ne 0) { throw "Study exited with code $LASTEXITCODE; see study.log" }
