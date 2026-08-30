# ![Kongroo](assets/icon-32.png) Kongroo.SampleApp

Scaffolded from the Kongroo solution template (`dotnet new kongroo-sln`). The repo starts empty —
conventions, hooks and CI are wired up, and you add projects with the adder templates.

## Getting started

```bash
dotnet tool restore       # CSharpier
pnpm install              # Prettier + commitlint
```

## Adding projects

Each adder creates a project on disk; it is not wired into the solution until you also run
`dotnet sln add` on its `.csproj`. The empty `.slnx` routes each project into the matching `/src/`
or `/test/` folder automatically, based on the path you give it.

```bash
dotnet new kongroo-api -n Kongroo.SampleApp.Api -o src/Kongroo.SampleApp.Api
dotnet sln add src/Kongroo.SampleApp.Api/Kongroo.SampleApp.Api.csproj

dotnet new kongroo-test -n Kongroo.SampleApp.UnitTests -o test/Kongroo.SampleApp.UnitTests
dotnet sln add test/Kongroo.SampleApp.UnitTests/Kongroo.SampleApp.UnitTests.csproj
```

The other adders follow the same two-command pattern:

```bash
dotnet new kongroo-worker  -n Kongroo.SampleApp.Worker -o src/Kongroo.SampleApp.Worker
dotnet new kongroo-cli     -n Kongroo.SampleApp.Cli    -o src/Kongroo.SampleApp.Cli
dotnet new kongroo-console -n Kongroo.SampleApp.Tool   -o src/Kongroo.SampleApp.Tool
dotnet new kongroo-lib     -n Kongroo.SampleApp.Domain -o src/Kongroo.SampleApp.Domain
dotnet new kongroo-itest   -n Kongroo.SampleApp.IntegrationTests -o test/Kongroo.SampleApp.IntegrationTests
# then: dotnet sln add <path passed to -o above>/<ProjectName>.csproj
```

## Package versions

`Directory.Packages.props` holds only the repo-wide analyzer and two glob imports. Each project owns
its own versions in a `Packages.props` next to its `.csproj`, and adders ship theirs already filled
in — so adding a project needs no version hunting.

Two things to know:

- `dotnet package add` always writes to the root `Directory.Packages.props`, never into a project's
  fragment. That works, it just does not stay tidy on its own.
- A `PackageVersion Update="…"` override must sit **below** the `<Import>` lines in the root file, or
  it silently does nothing.

## Publishing packages

Projects do not publish by default (`IsPackable` is `false` repo-wide). Create a publishable library
with `dotnet new kongroo-lib --packable`, then tag:

```bash
git tag v1.0.0 && git push --tags
```

`.github/workflows/release.yml` publishes every packable project to nuget.org via
**trusted publishing (OIDC)** — no API key. One-time setup:

1. Create a trusted-publishing policy at <https://www.nuget.org/account/trustedpublishing>:
   Repository = this repo, Workflow File = `release.yml`, Environment = `release`.
2. Repo **Settings → Environments → `release`** → add secret `NUGET_USER` = your
   nuget.org **profile name** (not email).
