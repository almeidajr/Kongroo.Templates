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
    '.github/workflows/ci.yml'
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

if ($drift) {
    $drift | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host 'SYNC OK' -ForegroundColor Green
