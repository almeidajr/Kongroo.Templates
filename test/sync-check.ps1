#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$drift = @()

# --- 1. kongroo-nuget shared conventions vs. kongroo-sln ---
# These files are byte-identical copies; any drift means one scaffolder is out of date.
$nugetDir = Join-Path $root 'templates/kongroo-nuget'
$slnDir   = Join-Path $root 'templates/kongroo-sln'

$sharedFiles = @(
    'Directory.Build.props',
    'Directory.Packages.props',
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
    'assets/icon-32.png',
    'assets/icon.png',
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

# --- 2. release.yml: identical apart from each template's own sourceName ---
# It cannot join $sharedFiles (the release title embeds sourceName), but everything
# else must match, and it has drifted unobserved before.
$sourceNames = @{ 'kongroo-sln' = 'Kongroo.SampleApp'; 'kongroo-nuget' = 'Kongroo.SampleLib' }
$normalized = @{}
foreach ($template in $sourceNames.Keys) {
    $path = Join-Path $root "templates/$template/.github/workflows/release.yml"
    if (-not (Test-Path $path)) { $drift += "MISSING release.yml in $template"; continue }
    $normalized[$template] = (Get-Content $path -Raw).Replace($sourceNames[$template], '<SOURCENAME>')
}
if ($normalized.Count -eq 2 -and $normalized['kongroo-sln'] -ne $normalized['kongroo-nuget']) {
    $drift += 'DRIFT: release.yml differs between kongroo-sln and kongroo-nuget beyond sourceName'
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
