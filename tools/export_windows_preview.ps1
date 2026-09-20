param(
    [string]$Godot = 'C:/Users/ysyki/Godot/Godot_console.exe',
    [string]$Ref = 'HEAD',
    [string]$ResultFile = ''
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
$revision = (& git -C $projectPath rev-parse --verify "$Ref^{commit}").Trim()
if ($LASTEXITCODE -ne 0 -or $revision -notmatch '^[0-9a-f]{40}$') { throw 'Ref must resolve to a commit' }

$buildRoot = Join-Path $projectPath ('docs/builds/windows-preview-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $revision.Substring(0, 8))
$sourceZip = Join-Path $buildRoot 'source.zip'
$sourcePath = Join-Path $buildRoot 'source'
$outputPath = Join-Path $buildRoot 'HACK-AND-SHMUP-preview.exe'
New-Item -ItemType Directory -Path $buildRoot | Out-Null
& git -C $projectPath archive --format=zip "--output=$sourceZip" $revision
if ($LASTEXITCODE -ne 0) { throw 'Cannot archive source commit' }
Expand-Archive -LiteralPath $sourceZip -DestinationPath $sourcePath

# The preview build must neither load nor distribute the telemetry SDK.
Remove-Item -LiteralPath (Join-Path $sourcePath 'addons/sentry') -Recurse -Force
$projectFile = Join-Path $sourcePath 'project.godot'
$projectText = Get-Content -LiteralPath $projectFile -Raw
$projectText = $projectText -replace '(?ms)^\[sentry\]\r?\n.*?(?=^\[|\z)', ''
[IO.File]::WriteAllText($projectFile, $projectText)

& $enginePath --headless --path $sourcePath --editor --import --disable-crash-handler --log-file (Join-Path $buildRoot 'import.log')
if ($LASTEXITCODE -ne 0) { throw 'Preview import failed' }
& $enginePath --headless --path $sourcePath --export-release 'Windows Preview' $outputPath --disable-crash-handler --log-file (Join-Path $buildRoot 'export.log')
if ($LASTEXITCODE -ne 0) { throw 'Windows Preview export failed' }

$files = @(Get-ChildItem -LiteralPath $buildRoot -File)
if ($files.Name -notcontains 'HACK-AND-SHMUP-preview.exe' -or $files.Count -ne 4) { throw 'Preview package must contain one executable plus build logs and source archive only' }
if ((Get-Item -LiteralPath $outputPath).Length -eq 0) { throw 'Preview executable is empty' }

& $enginePath --headless --main-pack $outputPath --script (Join-Path $PSScriptRoot 'verify_windows_preview.gd') --disable-crash-handler --log-file (Join-Path $buildRoot 'package.log')
if ($LASTEXITCODE -ne 0) { throw 'Preview package verification failed' }

$startupLog = Join-Path $buildRoot 'startup.log'
$process = Start-Process -FilePath $outputPath -WorkingDirectory $buildRoot -ArgumentList @('--headless', '--disable-crash-handler', '--log-file', ('"' + $startupLog + '"'), '--quit-after', '30') -WindowStyle Hidden -PassThru
if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Preview executable timed out' }
$process.Refresh()
$startupText = Get-Content -LiteralPath $startupLog -Raw
if ($process.ExitCode -ne 0 -or $startupText -match 'SCRIPT ERROR:|ERROR:' -or $startupText -notmatch 'Godot Engine') { throw 'Preview executable startup failed' }

if ($ResultFile) {
    [ordered]@{ revision = $revision; executable = $outputPath; sha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant() } | ConvertTo-Json | Set-Content -LiteralPath $ResultFile
}
Write-Output "PASS: Windows Preview exported from $revision"
Write-Output "Artifact: $outputPath"
