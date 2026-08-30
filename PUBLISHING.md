# Publishing `Kongroo.Templates` to nuget.org

The pack publishes via **NuGet trusted publishing (OIDC)** — no long-lived API
key. `.github/workflows/release.yml` runs on a `v*` tag, packs, pushes to nuget.org
using a short-lived token exchanged from GitHub's OIDC token, and creates the matching
GitHub Release. [MinVer](https://github.com/adamralph/minver) derives the package version
from the tag (`v1.2.3` → `1.2.3`) — there is no `<Version>` property to keep in sync.

## One-time setup (do this after the repo is on GitHub)

These steps need your nuget.org account and the GitHub repo — they cannot be
automated from a local checkout.

1. **Create the trusted-publishing policy** at
   <https://www.nuget.org/account/trustedpublishing> → **Add policy**:
   - **Repository Owner**: `almeidajr`
   - **Repository**: `Kongroo.Templates`
   - **Workflow File**: `release.yml` _(filename only — must match exactly, case-insensitive)_
   - **Environment**: `release`

   > Private repo? The policy is "temporarily active" for 7 days and becomes
   > permanent after the first successful publish.

2. **Create the GitHub Environment** `release`
   (repo **Settings → Environments → New environment → `release`**) and add an
   **environment secret**:
   - **Name**: `NUGET_USER`
   - **Value**: your nuget.org **profile name** (NOT your email)

   Optionally add **Required reviewers** for an approval gate before each publish.

## Releasing

```bash
# The tag is the version — MinVer reads it, so there is nothing to bump first.
git tag v0.2.0
git push origin main --tags
# release.yml publishes Kongroo.Templates 0.2.0 to nuget.org and opens the GitHub Release
```

## Notes

- `--skip-duplicate` makes re-runs idempotent (re-pushing an existing version is a no-op, not an error).
- The GitHub Release is created after the push succeeds, so a failed publish never leaves a release
  claiming otherwise. Its notes are the commit subjects since the previous tag, which is what
  `<PackageReleaseNotes>` points readers at. A tag with a prerelease suffix (`v1.0.0-preview.1`)
  is marked as a prerelease and does not become `Latest`.
- Generated repos (from `kongroo-sln` / `kongroo-nuget`) ship their own
  `release.yml` using the same OIDC pattern; each repo's packable libraries
  publish the same keyless way once its own trusted-publishing policy is created.
