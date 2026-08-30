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

# --- 4. PackageVersion consistency across all Packages.props fragments ---
# The Remove-then-Include idiom that keeps a fragment idempotent also suppresses NU1506, which is
# the only diagnostic that would otherwise catch two fragments disagreeing on a shared package's
# version. Without this check, a version bumped in one fragment only is resolved silently, by the
# alphabetical order of the importing project directories.
$fragments = Get-ChildItem (Join-Path $root 'templates') -Recurse -Filter 'Packages.props'
$fragmentVersions = @{}
foreach ($frag in $fragments) {
    $rel = [System.IO.Path]::GetRelativePath($root, $frag.FullName).Replace('\', '/')
    [xml]$fragXml = Get-Content $frag.FullName -Raw
    $removeNames = @()
    $includeNames = @()
    foreach ($node in $fragXml.SelectNodes('//PackageVersion')) {
        if ($node.Remove) { $removeNames += ($node.Remove -split ';' | Where-Object { $_ }) }
        if ($node.Include) {
            $includeNames += $node.Include
            if (-not $fragmentVersions.ContainsKey($node.Include)) { $fragmentVersions[$node.Include] = @{} }
            if (-not $fragmentVersions[$node.Include].ContainsKey($node.Version)) { $fragmentVersions[$node.Include][$node.Version] = @() }
            $fragmentVersions[$node.Include][$node.Version] += $rel
        }
    }
    $removeSet = $removeNames | Sort-Object -Unique
    $includeSet = $includeNames | Sort-Object -Unique
    foreach ($n in $removeSet | Where-Object { $includeSet -notcontains $_ }) {
        $drift += "PACKAGES.PROPS: $rel removes '$n' but never includes it"
    }
    foreach ($n in $includeSet | Where-Object { $removeSet -notcontains $_ }) {
        $drift += "PACKAGES.PROPS: $rel includes '$n' without removing it first; a second project of this adder will hit NU1506"
    }
}
foreach ($name in $fragmentVersions.Keys | Sort-Object) {
    if ($fragmentVersions[$name].Count -le 1) { continue }
    $detail = ($fragmentVersions[$name].Keys | Sort-Object | ForEach-Object { "$_ in $($fragmentVersions[$name][$_] -join ', ')" }) -join ' | '
    $drift += "PACKAGE VERSION DRIFT: $name pinned at $detail"
}

if ($drift) {
    $drift | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host 'SYNC OK' -ForegroundColor Green
