#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$art  = Join-Path $root 'artifacts'
$work = Join-Path ([System.IO.Path]::GetTempPath()) "kongroo-smoke-$([System.IO.Path]::GetRandomFileName())"
New-Item -ItemType Directory -Force -Path $work | Out-Null

# PackageIcon must resolve to a file at the package root, else nuget.org shows no icon.
function Assert-PackageIcon([string]$NupkgPath) {
    $name = Split-Path $NupkgPath -Leaf
    $zip = [System.IO.Compression.ZipFile]::OpenRead($NupkgPath)
    try {
        if (-not ($zip.Entries | Where-Object FullName -EQ 'icon.png')) { throw "icon.png missing from $name" }
        $nuspec = $zip.Entries | Where-Object FullName -Like '*.nuspec' | Select-Object -First 1
        if (-not $nuspec) { throw "nuspec missing from $name" }
        $reader = New-Object System.IO.StreamReader $nuspec.Open()
        try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
        if ($xml -notmatch '<icon>icon\.png</icon>') { throw "<icon> missing from nuspec in $name" }
    }
    finally { $zip.Dispose() }
}

# A config whose rules never fire passes CI like a working one. Prove they fire.
function Assert-StyleRulesFire([string]$ProjectDir) {
    $probe = Join-Path $ProjectDir 'StyleProbe.cs'
    @'
namespace StyleProbe;

public sealed class Probe
{
    public System.Collections.Generic.List<int> Items { get; set; } = [];

    public static int Run()
    {
        int Helper() => 42;
        return Helper();
    }
}
'@ | Set-Content -LiteralPath $probe -Encoding utf8
    try {
        $out = dotnet build $ProjectDir -warnaserror -p:ContinuousIntegrationBuild=false 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) { throw 'style probe compiled clean; the editorconfig rules are not firing' }
        foreach ($id in 'CA2227', 'IDE0062', 'IDE0130') {
            if ($out -notmatch $id) { throw "style probe failed but never reported $id; that rule is not firing" }
        }
    }
    finally { Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue }
}

# 1. Pack and install
dotnet pack (Join-Path $root 'Kongroo.Templates.csproj') -c Release -o $art
if ($LASTEXITCODE -ne 0) { throw 'pack failed' }

$nupkg = Get-ChildItem $art -Filter 'Kongroo.Templates.*.nupkg' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $nupkg) { throw 'nupkg not found in artifacts/' }
Assert-PackageIcon $nupkg.FullName

dotnet new install $nupkg.FullName --force
if ($LASTEXITCODE -ne 0) { throw 'template install failed' }

try {
    # 2. Scaffold solution  (sourceName=Kongroo.SampleApp → -n Kongroo.Smoke produces Kongroo.Smoke.*)
    $smokeDir = Join-Path $work 'Smoke'
    dotnet new kongroo-sln -n Kongroo.Smoke -o $smokeDir
    if ($LASTEXITCODE -ne 0) { throw 'kongroo-sln scaffold failed' }
    if (Test-Path (Join-Path $smokeDir '.template.config')) { throw '.template.config leaked into kongroo-sln output' }
    if (-not (Test-Path (Join-Path $smokeDir 'assets/icon-32.png'))) { throw 'assets/icon-32.png missing from kongroo-sln output' }

    # The shell must be empty: no projects, and both solution folders present so
    # `dotnet sln add` has somewhere to route src/ and test/ projects.
    if (Get-ChildItem $smokeDir -Recurse -Filter '*.csproj' -ErrorAction SilentlyContinue) {
        throw 'kongroo-sln emitted a project; the shell must be empty'
    }
    $slnxText = Get-Content (Join-Path $smokeDir 'Kongroo.Smoke.slnx') -Raw
    foreach ($folder in '"/src/"', '"/test/"') {
        if ($slnxText -notmatch [regex]::Escape($folder)) { throw "slnx is missing the $folder folder" }
    }

    # A zero-match glob import must be silently skipped, not an error.
    Push-Location $smokeDir
    dotnet restore
    if ($LASTEXITCODE -ne 0) { throw 'empty shell failed to restore' }
    Pop-Location

    # global.json must carry a full feature-band SDK version when rollForward is set,
    # else setup-dotnet (used by the scaffolded repo's CI) rejects it: "Version 'x.y.0' is not valid".
    $gj = Get-Content (Join-Path $smokeDir 'global.json') -Raw | ConvertFrom-Json
    if ($gj.sdk.rollForward -and $gj.sdk.version -notmatch '^\d+\.\d+\.\d{3}') {
        throw "global.json sdk.version '$($gj.sdk.version)' must be a full SDK version (e.g. 10.0.100) when rollForward is set"
    }

    Push-Location $smokeDir

    # 3. Restore tools (dotnet-format, etc.)
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw 'tool restore failed' }

    # 4. Generate adders; add each new csproj to the solution
    $slnx = 'Kongroo.Smoke.slnx'

    $adders = @(
        @{ Template = 'kongroo-api';     Name = 'Kongroo.Smoke.Api';       Dir = 'src' },
        @{ Template = 'kongroo-lib';     Name = 'Kongroo.Smoke.Domain';    Dir = 'src' },
        @{ Template = 'kongroo-test';    Name = 'Kongroo.Smoke.UnitTests'; Dir = 'test' },
        @{ Template = 'kongroo-itest';   Name = 'Kongroo.Smoke.E2ETests';  Dir = 'test' },
        @{ Template = 'kongroo-console'; Name = 'Kongroo.Smoke.Tool';      Dir = 'src' },
        @{ Template = 'kongroo-worker';  Name = 'Kongroo.Smoke.Ingest';    Dir = 'src' },
        @{ Template = 'kongroo-cli';     Name = 'Kongroo.Smoke.Cli';       Dir = 'src' }
    )

    foreach ($adder in $adders) {
        $out = "$($adder.Dir)/$($adder.Name)"
        dotnet new $adder.Template -n $adder.Name -o $out
        if ($LASTEXITCODE -ne 0) { throw "$($adder.Template) scaffold failed for $($adder.Name)" }
        dotnet sln $slnx add "$out/$($adder.Name).csproj"
        if ($LASTEXITCODE -ne 0) { throw "sln add failed for $($adder.Name)" }
    }

    # observability=false is otherwise never built, and the failure is silent: every OpenTelemetry
    # version now sits in the central Directory.Packages.props, so a conditional the template engine
    # failed to strip would leave real PackageReferences that restore and build clean - shipping
    # OpenTelemetry to someone who asked for none.
    foreach ($plain in @(
            @{ Template = 'kongroo-worker'; Name = 'Kongroo.Smoke.Plain' },
            @{ Template = 'kongroo-api'; Name = 'Kongroo.Smoke.ApiPlain' })) {
        dotnet new $plain.Template -n $plain.Name -o "src/$($plain.Name)" --observability false
        if ($LASTEXITCODE -ne 0) { throw "$($plain.Template) --observability false scaffold failed" }
        dotnet sln $slnx add "src/$($plain.Name)/$($plain.Name).csproj"
        if ($LASTEXITCODE -ne 0) { throw "sln add $($plain.Name) failed" }
        $csproj = Join-Path $smokeDir "src/$($plain.Name)/$($plain.Name).csproj"
        if (Select-String -Path $csproj -Pattern 'OpenTelemetry' -Quiet) {
            throw "observability=false left OpenTelemetry PackageReferences in $($plain.Name).csproj"
        }
        if (Select-String -Path $csproj -Pattern 'DefineConstants' -Quiet) {
            throw "observability=false left the observability DefineConstants in $($plain.Name).csproj"
        }
    }

    # sourceName is Kongroo.SampleApp.Console and the body says AnsiConsole. dotnet new replaces
    # the whole sourceName string, not the trailing segment - assert that rather than trusting it,
    # because a corrupted Program.cs would still be a valid-looking file.
    $toolProgram = Get-Content (Join-Path $smokeDir 'src/Kongroo.Smoke.Tool/Program.cs') -Raw
    if ($toolProgram -notmatch 'AnsiConsole\.MarkupLine') {
        throw 'sourceName substitution mangled the console template Program.cs'
    }

    # 5. Build. The Smoke service repo builds in a non-git temp dir; under CI
    # (GITHUB_ACTIONS=true) any CI-only step (SourceLink etc.) would try to read git
    # and fail. We verify buildability, not publishing, so force the CI build off.
    dotnet build -warnaserror -p:ContinuousIntegrationBuild=false
    if ($LASTEXITCODE -ne 0) { throw 'build failed' }

    # 5b. A clean build proves nothing about the kongroo-cli DI bridge or exception-handler
    # contract (e.g. a dropped UseAssemblyInformationalVersion, or GreetCommand failing to
    # resolve IAnsiConsole) - those are runtime-only failures. UseArtifactsOutput means the
    # binary isn't where a default build would put it, so `dotnet run --project` is simpler
    # than hunting the output path.
    $cliOutput = dotnet run --project src/Kongroo.Smoke.Cli -- greet World 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "kongroo-cli run failed with exit code ${LASTEXITCODE}: $cliOutput" }
    if ($cliOutput -notmatch 'Hello, World!') { throw "kongroo-cli greet did not print the expected greeting: $cliOutput" }

    # 5c. The worker resolves TimeProvider from DI, which the host does NOT register on its own -
    # drop the AddSingleton and the build still passes, the image still builds, and the container
    # dies on start with "Unable to resolve service for type 'System.TimeProvider'". Only running it
    # catches that. The sample ticks every 5s, so allow generous headroom.
    $workerLog = Join-Path $smokeDir 'worker-run.log'
    $worker = Start-Process dotnet -PassThru -NoNewWindow `
        -ArgumentList 'run', '--project', 'src/Kongroo.Smoke.Ingest' `
        -RedirectStandardOutput $workerLog -RedirectStandardError (Join-Path $smokeDir 'worker-run.err')
    try {
        $ticked = $false
        $deadline = (Get-Date).AddSeconds(90)
        while ((Get-Date) -lt $deadline -and -not $worker.HasExited) {
            Start-Sleep -Milliseconds 500
            if ((Test-Path $workerLog) -and (Select-String -Path $workerLog -Pattern 'Worker ran at' -Quiet)) {
                $ticked = $true
                break
            }
        }
    }
    finally {
        if (-not $worker.HasExited) { $worker.Kill($true) }
    }
    if (-not $ticked) {
        $tail = (Get-Content $workerLog -Tail 20 -ErrorAction SilentlyContinue) -join "`n"
        $err = (Get-Content (Join-Path $smokeDir 'worker-run.err') -Tail 20 -ErrorAction SilentlyContinue) -join "`n"
        throw "kongroo-worker never logged a tick:`n$tail`n$err"
    }

    # 5d. Build both images. Nothing exercised these Dockerfiles before, so a wrong COPY path or a
    # failing restore shipped silently. The build context is the repo root because CPM needs
    # Directory.Packages.props, which is also why .dockerignore lives there and not beside a csproj.
    if ((Get-Command docker -ErrorAction SilentlyContinue) -and (docker info 2>$null)) {
        foreach ($image in 'Api', 'Ingest') {
            $tag = "kongroo-smoke-$($image.ToLowerInvariant())"
            docker build -f "src/Kongroo.Smoke.$image/Dockerfile" -t $tag .
            if ($LASTEXITCODE -ne 0) { throw "docker build failed for Kongroo.Smoke.$image" }
            docker image rm -f $tag | Out-Null
        }
    }
    else {
        Write-Host 'Docker unavailable - skipping image builds' -ForegroundColor Yellow
    }

    # 6. Test (plain — no --tl:off, breaks MTP discovery)
    dotnet test
    if ($LASTEXITCODE -ne 0) { throw 'tests failed' }

    # A private library must not publish itself. IsPackable defaults to true for a classlib,
    # so without the repo-wide default an internal Domain project lands on nuget.org on the
    # first `git tag v1.0.0`.
    dotnet pack -c Release -o (Join-Path $smokeDir 'pkg') -p:ContinuousIntegrationBuild=false
    if ($LASTEXITCODE -ne 0) { throw 'solution pack failed' }
    $stray = Get-ChildItem (Join-Path $smokeDir 'pkg') -Filter '*.nupkg' -ErrorAction SilentlyContinue
    if ($stray) { throw "kongroo-sln repo produced packages nothing asked for: $($stray.Name -join ', ')" }

    # The packaging PackageReferences are gated by the same #if as these files, so a stray file
    # here fails nothing at build time - only this assertion catches it.
    foreach ($f in 'README.md', 'PublicAPI.Shipped.txt', 'PublicAPI.Unshipped.txt') {
        if (Test-Path (Join-Path $smokeDir "src/Kongroo.Smoke.Domain/$f")) {
            throw "plain kongroo-lib emitted packaging-only file $f"
        }
    }

    if (-not (Test-Path (Join-Path $smokeDir 'assets/icon.png'))) {
        throw 'assets/icon.png missing from kongroo-sln output; --packable cannot pack without it'
    }

    Assert-StyleRulesFire (Join-Path $smokeDir 'src/Kongroo.Smoke.Api')

    Pop-Location

    # 7. Standalone library-repo scaffolder
    $libDir = Join-Path $work 'Lib'
    dotnet new kongroo-nuget -n Kongroo.Foo -o $libDir
    if ($LASTEXITCODE -ne 0) { throw 'kongroo-nuget scaffold failed' }
    if (Test-Path (Join-Path $libDir '.template.config')) { throw '.template.config leaked into kongroo-nuget output' }
    if (-not (Test-Path (Join-Path $libDir 'assets/icon-32.png'))) { throw 'assets/icon-32.png missing from kongroo-nuget output' }
    # sourceName-substituted URL; 404s silently on nuget.org if the repo naming convention drifts.
    if ((Get-Content (Join-Path $libDir 'README.md') -TotalCount 1) -notmatch 'almeidajr/Kongroo\.Foo/main/assets/icon-32\.png') {
        throw 'README title logo URL did not substitute to the scaffolded project name'
    }
    Push-Location $libDir
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw 'lib tool restore failed' }

    # A package repo holds several packages; one v* tag ships them all at the same version.
    dotnet new kongroo-lib --packable -n Kongroo.Foo.Json -o src/Kongroo.Foo.Json
    if ($LASTEXITCODE -ne 0) { throw 'kongroo-lib --packable scaffold failed' }
    dotnet sln Kongroo.Foo.slnx add src/Kongroo.Foo.Json/Kongroo.Foo.Json.csproj
    if ($LASTEXITCODE -ne 0) { throw 'sln add Kongroo.Foo.Json failed' }
    if (-not (Test-Path (Join-Path $libDir 'src/Kongroo.Foo.Json/README.md'))) {
        throw '--packable did not emit a per-package README'
    }

    # non-git temp dir: disable CI build so SourceLink (CI-guarded on under GITHUB_ACTIONS) doesn't error
    dotnet build -warnaserror -p:ContinuousIntegrationBuild=false
    if ($LASTEXITCODE -ne 0) { throw 'lib build failed' }
    dotnet test
    if ($LASTEXITCODE -ne 0) { throw 'lib tests failed' }
    dotnet pack -c Release -o (Join-Path $libDir 'pkg') -p:ContinuousIntegrationBuild=false
    if ($LASTEXITCODE -ne 0) { throw 'lib pack failed' }
    $nupkgs = Get-ChildItem (Join-Path $libDir 'pkg') -Filter '*.nupkg'
    if ($nupkgs.Count -ne 2) {
        throw "expected 2 packages (Kongroo.Foo, Kongroo.Foo.Json), got $($nupkgs.Count): $($nupkgs.Name -join ', ')"
    }
    if ((Get-ChildItem (Join-Path $libDir 'pkg') -Filter '*.snupkg').Count -ne 2) { throw 'expected 2 symbol packages' }
    foreach ($pkg in $nupkgs) { Assert-PackageIcon $pkg.FullName }
    Pop-Location

    Write-Host 'SMOKE OK' -ForegroundColor Green
}
finally {
    if ((Get-Location).Path -eq $smokeDir -or (Get-Location).Path -eq $libDir) { Pop-Location }
    dotnet new uninstall Kongroo.Templates | Out-Null
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
