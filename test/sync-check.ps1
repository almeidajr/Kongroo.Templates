#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

# --- 1. kongroo-api adder vs. sln copy ---
# Only kongroo-api is a verbatim copy of the sln API; test/itest adders intentionally diverge.
$apiSrc = Join-Path $root 'templates/kongroo-sln/src/Kongroo.SampleApp.Api'
$apiAdder = Join-Path $root 'templates/kongroo-api'

$apiFiles = @(
    'Kongroo.SampleApp.Api.csproj',
    'Program.cs',
    'appsettings.json',
    'appsettings.Development.json',
    'Properties/launchSettings.json',
    'Dockerfile',
    '.dockerignore'
)

$drift = @()
foreach ($f in $apiFiles) {
    $a = Join-Path $apiAdder $f
    $b = Join-Path $apiSrc $f
    if (-not (Test-Path $a)) { $drift += "MISSING in adder: $f"; continue }
    if (-not (Test-Path $b)) { $drift += "MISSING in sln: $f"; continue }
    if ((Get-FileHash $a).Hash -ne (Get-FileHash $b).Hash) {
        $drift += "DRIFT: templates/kongroo-api/$f differs from templates/kongroo-sln/src/Kongroo.SampleApp.Api/$f"
    }
}

# --- 2. kongroo-nuget shared conventions vs. kongroo-sln ---
# These files are byte-identical copies; any drift means one scaffolder is out of date.
$nugetDir = Join-Path $root 'templates/kongroo-nuget'
$slnDir   = Join-Path $root 'templates/kongroo-sln'

$sharedFiles = @(
    'Directory.Build.props',
    '.editorconfig',
    '.gitignore',
    '.gitattributes',
    'dotnet-tools.json',
    'package.json',
    'pnpm-lock.yaml',
    '.prettierrc',
    '.prettierignore',
    'commitlint.config.cjs',
    '.pre-commit-config.yaml',
    'LICENSE',
    'global.json',
    'nuget.config',
    '.github/workflows/ci.yml',
    '.github/dependabot.yml'
)

foreach ($f in $sharedFiles) {
    $a = Join-Path $nugetDir $f
    $b = Join-Path $slnDir $f
    if (-not (Test-Path $a)) { $drift += "MISSING in kongroo-nuget: $f"; continue }
    if (-not (Test-Path $b)) { $drift += "MISSING in kongroo-sln: $f"; continue }
    if ((Get-FileHash $a).Hash -ne (Get-FileHash $b).Hash) {
        $drift += "DRIFT: templates/kongroo-nuget/$f differs from templates/kongroo-sln/$f"
    }
}

# --- 3. Action versions across every workflow (root + templates) ---
# Dependabot only bumps the root copies; this makes the templates follow instead of drifting.
# -Filter is silently ignored when -Path holds a wildcard, so enumerate the dirs explicitly.
$workflowDirs = @(Join-Path $root '.github/workflows') + (
    Get-ChildItem (Join-Path $root 'templates') -Directory |
        ForEach-Object { Join-Path $_.FullName '.github/workflows' } |
        Where-Object { Test-Path $_ }
)
$workflows = $workflowDirs | ForEach-Object { Get-ChildItem -File -Filter '*.yml' -Path $_ }
$actions = @{}
foreach ($w in $workflows) {
    $rel = [System.IO.Path]::GetRelativePath($root, $w.FullName).Replace('\', '/')
    foreach ($m in [regex]::Matches((Get-Content $w.FullName -Raw), '(?m)uses:\s*(?<name>[^@\s]+)@(?<ver>\S+)')) {
        $name = $m.Groups['name'].Value
        $ver = $m.Groups['ver'].Value
        if (-not $actions.ContainsKey($name)) { $actions[$name] = @{} }
        if (-not $actions[$name].ContainsKey($ver)) { $actions[$name][$ver] = @() }
        $actions[$name][$ver] += $rel
    }
}
foreach ($name in $actions.Keys | Sort-Object) {
    if ($actions[$name].Count -le 1) { continue }
    $detail = ($actions[$name].Keys | Sort-Object | ForEach-Object { "$_ in $($actions[$name][$_] -join ', ')" }) -join ' | '
    $drift += "ACTION DRIFT: $name pinned at $detail"
}
if ($drift) {
    $drift | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host 'SYNC OK' -ForegroundColor Green
