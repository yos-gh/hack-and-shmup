param(
    [Parameter(Mandatory)][string]$Godot,
    [string]$Ref = 'HEAD',
    [ValidateNotNullOrEmpty()][ValidateSet('Web','Windows')][string[]]$Targets = @('Web','Windows')
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$revision = (& git -C $projectPath rev-parse --verify "$Ref^{commit}").Trim()
if ($LASTEXITCODE -ne 0 -or $revision -notmatch '^[0-9a-f]{40}$') { throw 'Invalid build revision' }
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw 'Godot executable is missing' }
& python (Join-Path $PSScriptRoot 'test_build_verifier.py')
if ($LASTEXITCODE -ne 0) { throw 'Build verifier self-tests failed' }
$reportRoot = Join-Path $projectPath ('docs/ci/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $reportRoot | Out-Null
$reports = @()
$artifactPaths = @()
foreach ($target in ($Targets | Select-Object -Unique)) {
    $resultFile = Join-Path $reportRoot ($target + '.json')
    & (Join-Path $PSScriptRoot 'build.ps1') -Godot $Godot -Ref $revision -Target $target -ResultFile $resultFile
    $result = Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
    if ($result.revision -ne $revision -or $result.target -ne $target) { throw 'Build result does not match requested source/target' }
    & python (Join-Path $PSScriptRoot 'verify_build.py') $result.build_directory
    if ($LASTEXITCODE -ne 0) { throw "Artifact verification failed: $target" }
    $reports += $result
    foreach ($pattern in @('*.zip','manifest.json','*.log','source/docs/validation/*.log','source/docs/validation/tests.json')) {
        $artifactPaths += (Join-Path $result.build_directory $pattern)
    }
}
$reports | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $reportRoot 'verified-builds.json')
if ($env:GITHUB_OUTPUT) {
    $delimiter = 'CI_' + [guid]::NewGuid().ToString('N')
    @("artifacts<<$delimiter") + $artifactPaths + @($delimiter) | Add-Content -LiteralPath $env:GITHUB_OUTPUT
}
Write-Output "PASS: CI source $revision; verified targets: $($reports.target -join ', ')"
Write-Output "Report: $reportRoot"
