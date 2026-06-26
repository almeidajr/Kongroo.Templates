# 🦘 Kongroo.Templates

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

| Template          | Short name      | Scaffolds                                                                                                                        |
| ----------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Solution          | `kongroo-sln`   | A full repo: `.slnx`, build conventions, formatting + git hooks, GitHub Actions, a Web API project, and unit + integration tests |
| Class library     | `kongroo-lib`   | A plain class library                                                                                                            |
| Web API           | `kongroo-api`   | An ASP.NET Core minimal API (Serilog, OpenTelemetry, Scalar, health checks, problem details, validation, Dockerfile)             |
| NuGet package     | `kongroo-nuget` | A packable, OSS-ready library (SourceLink, symbols, MIT metadata, packed README)                                                 |
| Unit tests        | `kongroo-test`  | An xUnit v3 project on Microsoft Testing Platform (Bogus, NSubstitute, Shouldly)                                                 |
| Integration tests | `kongroo-itest` | An xUnit v3 project with `WebApplicationFactory` + Testcontainers                                                                |

## Getting started

Scaffold a new solution. The `Kongroo.` prefix is fixed and `-n` supplies the application name:

```bash
dotnet new kongroo-sln -n Billing
# → ./Billing with Kongroo.Billing.Api, Kongroo.Billing.UnitTests, Kongroo.Billing.IntegrationTests
```

Add more projects to an existing Kongroo solution (adders take the full project name and print the
exact `dotnet sln add` command to wire themselves in):

```bash
cd Billing
dotnet new kongroo-lib   -n Kongroo.Billing.Domain   -o src/Kongroo.Billing.Domain
dotnet new kongroo-nuget -n Kongroo.Billing.Sdk      -o src/Kongroo.Billing.Sdk
dotnet new kongroo-itest -n Kongroo.Billing.E2ETests -o test/Kongroo.Billing.E2ETests
```

### Options

The solution template exposes a couple of switches:

```bash
dotnet new kongroo-sln -n Billing --integration-tests false   # omit the integration-test project
dotnet new kongroo-sln -n Billing --observability false       # omit OpenTelemetry wiring + packages
```

The Web API adder also accepts `--observability`.

## What's baked in

- **Target**: `net10.0`, nullable + implicit usings, warnings-as-errors, latest .NET analyzers.
- **Solution & packages**: `.slnx` format and Central Package Management (`Directory.Packages.props`).
- **Formatting & hooks**: CSharpier (C#), Prettier (JSON/YAML/Markdown), commitlint (Conventional
  Commits) — orchestrated by pre-commit, with a repo-root tool manifest.
- **Testing**: xUnit v3 on Microsoft Testing Platform, with Bogus, NSubstitute, and Shouldly;
  integration tests use `WebApplicationFactory` and Testcontainers.
- **Web API**: Serilog (with enrichers), OpenTelemetry tracing + metrics, the Scalar API reference,
  health checks (`/health`, `/alive`), problem-details error handling, minimal-API validation, and
  a multi-stage HTTP-only Dockerfile.
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
