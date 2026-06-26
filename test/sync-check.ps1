#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

# Only kongroo-api is a verbatim copy of the sln API; test/itest adders intentionally diverge.
$apiSrc = Join-Path $root 'templates\kongroo-sln\src\Kongroo.SampleApp.Api'
$apiAdder = Join-Path $root 'templates\kongroo-api'

$files = @(
    'Kongroo.SampleApp.Api.csproj',
    'Program.cs',
    'appsettings.json',
    'appsettings.Development.json',
    'Properties\launchSettings.json',
    'Dockerfile',
    '.dockerignore'
)

$drift = @()
foreach ($f in $files) {
    $a = Join-Path $apiAdder $f
    $b = Join-Path $apiSrc $f
    if (-not (Test-Path $a)) { $drift += "MISSING in adder: $f"; continue }
    if (-not (Test-Path $b)) { $drift += "MISSING in sln: $f"; continue }
    if ((Get-FileHash $a).Hash -ne (Get-FileHash $b).Hash) {
        $drift += "DRIFT: templates/kongroo-api/$f differs from templates/kongroo-sln/src/Kongroo.SampleApp.Api/$f"
    }
}

if ($drift) {
    $drift | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host 'SYNC OK' -ForegroundColor Green
