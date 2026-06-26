#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$art  = Join-Path $root 'artifacts'
$work = Join-Path ([System.IO.Path]::GetTempPath()) "kongroo-smoke-$([System.IO.Path]::GetRandomFileName())"
New-Item -ItemType Directory -Force -Path $work | Out-Null

# 1. Pack and install
dotnet pack (Join-Path $root 'Kongroo.Templates.csproj') -c Release -o $art
if ($LASTEXITCODE -ne 0) { throw 'pack failed' }

$nupkg = Get-ChildItem $art -Filter 'Kongroo.Templates.*.nupkg' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $nupkg) { throw 'nupkg not found in artifacts/' }

dotnet new install $nupkg.FullName --force
if ($LASTEXITCODE -ne 0) { throw 'template install failed' }

try {
    # 2. Scaffold solution  (sourceName=SampleApp → -n Smoke produces Kongroo.Smoke.*)
    $smokeDir = Join-Path $work 'Smoke'
    dotnet new kongroo-sln -n Smoke -o $smokeDir
    if ($LASTEXITCODE -ne 0) { throw 'kongroo-sln scaffold failed' }

    Push-Location $smokeDir

    # 3. Restore tools (dotnet-format, etc.)
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw 'tool restore failed' }

    # 4. Generate adders; add each new csproj to the solution
    $slnx = 'Kongroo.Smoke.slnx'

    dotnet new kongroo-lib   -n Kongroo.Smoke.Domain  -o src/Kongroo.Smoke.Domain
    if ($LASTEXITCODE -ne 0) { throw 'kongroo-lib scaffold failed' }
    dotnet sln $slnx add src/Kongroo.Smoke.Domain/Kongroo.Smoke.Domain.csproj
    if ($LASTEXITCODE -ne 0) { throw 'sln add Domain failed' }

    dotnet new kongroo-api   -n Kongroo.Smoke.Gateway  -o src/Kongroo.Smoke.Gateway
    if ($LASTEXITCODE -ne 0) { throw 'kongroo-api scaffold failed' }
    dotnet sln $slnx add src/Kongroo.Smoke.Gateway/Kongroo.Smoke.Gateway.csproj
    if ($LASTEXITCODE -ne 0) { throw 'sln add Gateway failed' }

    dotnet new kongroo-test  -n Kongroo.Smoke.MoreTests  -o test/Kongroo.Smoke.MoreTests
    if ($LASTEXITCODE -ne 0) { throw 'kongroo-test scaffold failed' }
    dotnet sln $slnx add test/Kongroo.Smoke.MoreTests/Kongroo.Smoke.MoreTests.csproj
    if ($LASTEXITCODE -ne 0) { throw 'sln add MoreTests failed' }

    dotnet new kongroo-itest -n Kongroo.Smoke.E2ETests   -o test/Kongroo.Smoke.E2ETests
    if ($LASTEXITCODE -ne 0) { throw 'kongroo-itest scaffold failed' }
    dotnet sln $slnx add test/Kongroo.Smoke.E2ETests/Kongroo.Smoke.E2ETests.csproj
    if ($LASTEXITCODE -ne 0) { throw 'sln add E2ETests failed' }

    # 5. Build. The smoke build runs in a non-git temp dir; in CI (GITHUB_ACTIONS=true)
    # the kongroo-nuget project would turn SourceLink on and fail ("unable to locate
    # repository"). We verify buildability, not publishing, so force SourceLink off.
    dotnet build -warnaserror -p:ContinuousIntegrationBuild=false
    if ($LASTEXITCODE -ne 0) { throw 'build failed' }

    # 6. Test (plain — no --tl:off, breaks MTP discovery)
    dotnet test
    if ($LASTEXITCODE -ne 0) { throw 'tests failed' }

    Pop-Location

    # 7. Standalone library-repo scaffolder
    $libDir = Join-Path $work 'Lib'
    dotnet new kongroo-nuget -n Foo -o $libDir
    if ($LASTEXITCODE -ne 0) { throw 'kongroo-nuget scaffold failed' }
    Push-Location $libDir
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw 'lib tool restore failed' }
    dotnet build -warnaserror
    if ($LASTEXITCODE -ne 0) { throw 'lib build failed' }
    dotnet test
    if ($LASTEXITCODE -ne 0) { throw 'lib tests failed' }
    dotnet pack -c Release -o (Join-Path $libDir 'pkg')
    if ($LASTEXITCODE -ne 0) { throw 'lib pack failed' }
    if (-not (Get-ChildItem (Join-Path $libDir 'pkg') -Filter '*.nupkg')) { throw 'no nupkg produced' }
    if (-not (Get-ChildItem (Join-Path $libDir 'pkg') -Filter '*.snupkg')) { throw 'no snupkg produced' }
    Pop-Location

    Write-Host 'SMOKE OK' -ForegroundColor Green
}
finally {
    if ((Get-Location).Path -eq $smokeDir -or (Get-Location).Path -eq $libDir) { Pop-Location }
    dotnet new uninstall Kongroo.Templates | Out-Null
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
