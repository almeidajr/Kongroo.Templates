# Kongroo.SampleApp

Scaffolded from the Kongroo solution template (`dotnet new kongroo-sln`).

## Getting started

```bash
dotnet tool restore       # CSharpier
pnpm install              # Prettier + commitlint
dotnet build
dotnet test
dotnet run --project src/Kongroo.SampleApp.Api
```

## Publishing packages

`.github/workflows/release.yml` publishes packable projects to nuget.org via
**trusted publishing (OIDC)** — no API key — on a `v*` tag. One-time setup:

1. Create a trusted-publishing policy at <https://www.nuget.org/account/trustedpublishing>:
   Repository = this repo, Workflow File = `release.yml`, Environment = `release`.
2. Repo **Settings → Environments → `release`** → add secret `NUGET_USER` = your
   nuget.org **profile name** (not email).

Then `git tag v1.0.0 && git push --tags` to publish.
