param(
    [ValidateSet('normal11', 'normal19', 'citadel5', 'bastion15', 'triad45')][string]$Scenario = 'normal19',
    [ValidateRange(0, 2)][int]$Weapon = 1,
    [ValidateRange(0,40)][double]$Tilt = 25,
    [int]$Seed = 19045,
    [ValidateRange(0, 999)][int]$Floor = 0,
    [ValidateRange(-1, 3)][int]$Boss = -1,
    [string]$Godot = 'C:/Users/ysyki/Godot/Godot_console.exe'
)
$projectPath = Split-Path -Parent $PSScriptRoot
$floorArgs = if ($Floor -gt 0) { @("--floor=$Floor", "--boss=$Boss") } else { @() }
& $Godot --path $projectPath --disable-crash-handler --log-file "$projectPath/study.log" --script res://tools/scenario.gd -- "--scenario=$Scenario" "--seed=$Seed" "--weapon=$Weapon" --frames=0 --view=3d "--tilt=$($Tilt.ToString([System.Globalization.CultureInfo]::InvariantCulture))" @floorArgs
if ($LASTEXITCODE -ne 0) { throw "Study exited with code $LASTEXITCODE; see study.log" }
