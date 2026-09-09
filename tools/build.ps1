param(
    [string]$Godot = 'C:/Users/ysyki/Godot/Godot_console.exe',
    [string]$Ref = 'HEAD',
    [ValidateSet('Web','Windows')][string]$Target = 'Web'
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
$revision = (& git -C $projectPath rev-parse --verify "$Ref^{commit}").Trim()
if ($LASTEXITCODE -ne 0 -or $revision -notmatch '^[0-9a-f]{40}$') { throw 'Ref must resolve to a commit' }
$buildRoot = Join-Path $projectPath ('docs/builds/' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $revision.Substring(0,8) + '-' + [guid]::NewGuid().ToString('N').Substring(0,6))
New-Item -ItemType Directory -Path $buildRoot | Out-Null
$sourceZip = Join-Path $buildRoot 'source.zip'
& git -C $projectPath archive --format=zip "--output=$sourceZip" $revision
if ($LASTEXITCODE -ne 0) { throw 'Cannot archive source commit' }
$sourcePath = Join-Path $buildRoot 'source'
Expand-Archive -LiteralPath $sourceZip -DestinationPath $sourcePath
$lockPath = Join-Path $sourcePath 'tools/toolchain.json'
if (-not (Test-Path -LiteralPath $lockPath)) { throw 'This commit has no toolchain lock' }
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
$version = (& $enginePath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne $lock.godot_version) { throw "Engine mismatch: expected $($lock.godot_version), got $version" }
$release = "hack-and-shmup@$revision"
$projectFile = Join-Path $sourcePath 'project.godot'
$projectText = Get-Content -LiteralPath $projectFile -Raw
if ($projectText -notmatch '(?m)^options/release=') { throw 'Missing Sentry release setting' }
$projectText = $projectText -replace '(?m)^options/release=.*$', ('options/release="' + $release + '"')
[IO.File]::WriteAllText($projectFile,$projectText)
$validationPath = Join-Path $sourcePath 'docs/validation'
New-Item -ItemType Directory -Force -Path $validationPath | Out-Null
function Invoke-CheckedGodot([string[]]$EngineArguments, [string]$LogFile) {
    & $enginePath --headless --path $sourcePath --disable-crash-handler --log-file $LogFile @EngineArguments
    if ($LASTEXITCODE -ne 0) { throw "Godot failed; see $LogFile" }
    if (-not (Test-Path -LiteralPath $LogFile)) { throw "Missing log: $LogFile" }
    if ((Get-Content -LiteralPath $LogFile -Raw) -match 'SCRIPT ERROR:|ERROR:') { throw "Godot logged errors; see $LogFile" }
}
Invoke-CheckedGodot @('--editor','--import') (Join-Path $buildRoot 'import.log')
& (Join-Path $sourcePath 'tools/test.ps1') -Godot $enginePath
$testResults = @(Get-Content -LiteralPath (Join-Path $validationPath 'tests.json') -Raw | ConvertFrom-Json)
if ($testResults.Count -eq 0 -or @($testResults | Where-Object { -not $_.Passed }).Count -gt 0) { throw 'Regression report is empty or failed' }
$folder = $Target.ToLowerInvariant()
$preset = $lock.export_preset
$entryFile = 'game-v2.html'
if ($Target -eq 'Windows') {
    if (-not $lock.windows_preset) { throw 'This commit has no Windows preset lock' }
    $preset = $lock.windows_preset
    $entryFile = 'hack-and-shmup.exe'
}
$exportPath = Join-Path $buildRoot $folder
New-Item -ItemType Directory -Path $exportPath | Out-Null
Invoke-CheckedGodot @('--export-release', $preset, (Join-Path $exportPath $entryFile)) (Join-Path $buildRoot 'export.log')
# Package the commit's landing page along with its freshly built engine files.
if ($Target -eq 'Web') { Copy-Item -LiteralPath (Join-Path $sourcePath 'web/index.html') -Destination $exportPath }
[ordered]@{ revision = $revision; engine = $version; release = $release } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $exportPath 'build-info.json')
$required = @('index.html','game-v2.html','game-v2.js','game-v2.wasm','game-v2.pck')
if ($Target -eq 'Windows') { $required = @('hack-and-shmup.exe','hack-and-shmup.pck','libsentry.windows.release.x86_64.dll','crashpad_handler.exe','crashpad_wer.dll') }
foreach ($name in $required) {
    $file = Join-Path $exportPath $name
    if (-not (Test-Path -LiteralPath $file) -or (Get-Item -LiteralPath $file).Length -eq 0) { throw "Missing or empty artifact: $name" }
}
$startupVerified = $false
if ($Target -eq 'Windows') {
    $startupLog = Join-Path $buildRoot 'windows-startup.log'
    $process = Start-Process -FilePath (Join-Path $exportPath $entryFile) -WorkingDirectory $exportPath -ArgumentList @('--headless','--disable-crash-handler','--log-file',('"' + $startupLog + '"'),'--quit-after','30') -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Exported Windows executable timed out' }
    $process.Refresh()
    $startupText = Get-Content -LiteralPath $startupLog -Raw
    if ($process.ExitCode -ne 0 -or $startupText -match 'SCRIPT ERROR:|ERROR:' -or $startupText -notmatch 'Godot Engine') { throw 'Exported Windows startup failed' }
    $startupVerified = $true
}
$files = @(Get-ChildItem -LiteralPath $exportPath -File -Recurse | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = [IO.Path]::GetRelativePath($exportPath,$_.FullName).Replace('\','/'); bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$package = Join-Path $buildRoot ($folder + '.zip')
Compress-Archive -Path (Join-Path $exportPath '*') -DestinationPath $package
$manifest = [ordered]@{
    schema = 1; revision = $revision; engine = $version; release = $release
    generated_project_sha256 = (Get-FileHash -LiteralPath $projectFile -Algorithm SHA256).Hash.ToLowerInvariant()
    engine_sha256 = (Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash.ToLowerInvariant()
    source_sha256 = (Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash.ToLowerInvariant()
    package_sha256 = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
    target = $Target; startup_verified = $startupVerified; preset = $preset; tests = $testResults; files = $files
    verification = 'Local import, native regressions and target export. Windows startup is headless only; interactive playback and deployment are not verified.'
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $buildRoot 'manifest.json')
Write-Output "PASS: verified commit build $revision"
Write-Output "Artifacts: $buildRoot"
