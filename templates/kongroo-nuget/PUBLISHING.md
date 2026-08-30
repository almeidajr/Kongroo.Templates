# Publishing this package to nuget.org

This repo publishes via **NuGet trusted publishing (OIDC)** — no API key.
`.github/workflows/release.yml` runs on a `v*` tag, packs, and pushes to nuget.org.
[MinVer](https://github.com/adamralph/minver) derives the package version from the
tag (`v1.2.3` → `1.2.3`).

## One-time setup

1. Create a trusted-publishing policy at
   <https://www.nuget.org/account/trustedpublishing> → **Add policy**:
   - **Repository**: this repo (your GitHub owner + name)
   - **Workflow File**: `release.yml`
   - **Environment**: `release`
2. Repo **Settings → Environments → `release`** → add secret `NUGET_USER` = your
   nuget.org **profile name** (not email).

## Releasing

```bash
git tag v1.0.0 && git push origin v1.0.0
```

The release workflow packs the project, publishes the version derived from the tag, and
creates the matching GitHub Release with the commit subjects since the previous tag.
`--skip-duplicate` makes re-runs safe; a prerelease tag (`v1.0.0-preview.1`) is marked as a
prerelease and does not become `Latest`.
