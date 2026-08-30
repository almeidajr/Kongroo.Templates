# ![Kongroo](https://raw.githubusercontent.com/almeidajr/Kongroo.Templates/main/assets/icon-32.png) Kongroo.Templates

[![CI](https://github.com/almeidajr/Kongroo.Templates/actions/workflows/ci.yml/badge.svg)](https://github.com/almeidajr/Kongroo.Templates/actions/workflows/ci.yml)
[![NuGet](https://img.shields.io/nuget/v/Kongroo.Templates.svg)](https://www.nuget.org/packages/Kongroo.Templates)
[![Downloads](https://img.shields.io/nuget/dt/Kongroo.Templates.svg)](https://www.nuget.org/packages/Kongroo.Templates)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/almeidajr/Kongroo.Templates/blob/main/LICENSE)

Opinionated `dotnet new` starter templates for my personal .NET projects — a solution
scaffolder plus standalone project "adders", with my conventions baked in so a new repo is
build-, test-, format-, and publish-ready from the first commit.

## Installation

```bash
dotnet new install Kongroo.Templates
```

Update to the latest version with `dotnet new install Kongroo.Templates::<version>`, and remove
it with `dotnet new uninstall Kongroo.Templates`.

## Templates

| Template          | Short name        | Scaffolds                                                                                                |
| ----------------- | ----------------- | -------------------------------------------------------------------------------------------------------- |
| Solution          | `kongroo-sln`     | An empty repo: `.slnx`, build conventions, formatting + git hooks, GitHub Actions. No projects.          |
| NuGet package     | `kongroo-nuget`   | A publishable package repo (solution + library + tests + CI/OIDC publish)                                |
| Web API           | `kongroo-api`     | An ASP.NET Core minimal API (Serilog, OpenTelemetry, Scalar, health checks, problem details, Dockerfile) |
| Worker service    | `kongroo-worker`  | A Generic Host `BackgroundService` (Serilog, OpenTelemetry, Dockerfile)                                  |
| CLI app           | `kongroo-cli`     | A Spectre.Console `CommandApp` wired onto Microsoft.Extensions.DependencyInjection                       |
| Console app       | `kongroo-console` | A plain console app, no packages                                                                         |
| Class library     | `kongroo-lib`     | A class library; `--packable` makes it publishable                                                       |
| Unit tests        | `kongroo-test`    | An xUnit v3 project on Microsoft Testing Platform (Bogus, NSubstitute, Shouldly)                         |
| Integration tests | `kongroo-itest`   | An xUnit v3 project with `WebApplicationFactory` + Testcontainers                                        |

## Getting started

Scaffold an empty repo, then add the projects you want:

```bash
dotnet new kongroo-sln -n Kongroo.Billing
cd Kongroo.Billing

dotnet new kongroo-api  -n Kongroo.Billing.Api       -o src/Kongroo.Billing.Api
dotnet new kongroo-test -n Kongroo.Billing.UnitTests -o test/Kongroo.Billing.UnitTests
dotnet sln add src/Kongroo.Billing.Api/Kongroo.Billing.Api.csproj
dotnet sln add test/Kongroo.Billing.UnitTests/Kongroo.Billing.UnitTests.csproj
```

Scaffold a package repo, which comes with its first library already wired up:

```bash
dotnet new kongroo-nuget -n Kongroo.Acme
cd Kongroo.Acme
dotnet new kongroo-lib --packable -n Kongroo.Acme.Json -o src/Kongroo.Acme.Json
```

### Options

| Template                        | Option            | Effect                                                                     |
| ------------------------------- | ----------------- | -------------------------------------------------------------------------- |
| `kongroo-api`, `kongroo-worker` | `--observability` | OpenTelemetry tracing + metrics (default on)                               |
| `kongroo-lib`                   | `--packable`      | Packaging metadata, MinVer, SourceLink, public-API analyzers (default off) |

## What's baked in

- **Target**: `net10.0`, nullable + implicit usings, warnings-as-errors, latest .NET analyzers.
- **Solution & packages**: `.slnx` format and Central Package Management. Each project owns its versions in a `Packages.props` beside its `.csproj`; the root `Directory.Packages.props` holds the repo-wide analyzer and glob-imports the rest. Publishing is opt-in — `IsPackable` is `false` repo-wide, so a private library cannot reach nuget.org by accident.
- **Formatting & hooks**: CSharpier (C#), Prettier (JSON/YAML/Markdown), commitlint (Conventional
  Commits) — orchestrated by pre-commit, with a repo-root tool manifest.
- **Testing**: xUnit v3 on Microsoft Testing Platform, with Bogus, NSubstitute, and Shouldly;
  integration tests use `WebApplicationFactory` and Testcontainers.
- **Web API**: Serilog (with enrichers), OpenTelemetry tracing + metrics, the Scalar API reference,
  health checks (`/health`, `/alive`), problem-details error handling, and a multi-stage HTTP-only Dockerfile.
- **Worker service**: Serilog (with enrichers), OpenTelemetry tracing + metrics, and a multi-stage
  Dockerfile.
- **CLI app**: Spectre.Console commands wired onto Microsoft.Extensions.DependencyInjection.
- **CI/CD**: GitHub Actions for build/test, plus keyless publishing to nuget.org via
  [trusted publishing (OIDC)](https://learn.microsoft.com/nuget/nuget-org/trusted-publishing).

## Requirements

- [.NET 10 SDK](https://dotnet.microsoft.com/download) or later.
- For the generated repo's git hooks (optional but recommended): [pnpm](https://pnpm.io) (Prettier +
  commitlint) and [pre-commit](https://pre-commit.com).

## Publishing generated packages

Generated repos publish their packable projects to nuget.org keylessly via OIDC. See
[PUBLISHING.md](https://github.com/almeidajr/Kongroo.Templates/blob/main/PUBLISHING.md) for the
one-time nuget.org + GitHub setup, then tag a release:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

## Build & contribute

This repo dogfoods the same conventions it ships. From the repo root:

```bash
dotnet tool restore                 # CSharpier
pnpm install                        # Prettier + commitlint
pwsh test/sync-check.ps1            # guard the kongroo-api adder against drift from the sln copy
pwsh test/smoke-test.ps1            # pack → install → scaffold every template → build → test
dotnet csharpier check .            # formatting (also enforced in CI)
pnpm exec prettier --check .
```

## License

[MIT](https://github.com/almeidajr/Kongroo.Templates/blob/main/LICENSE)
