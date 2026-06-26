# Publishing `Kongroo.Templates` to nuget.org

The pack publishes via **NuGet trusted publishing (OIDC)** — no long-lived API
key. `.github/workflows/release.yml` runs on a `v*` tag, validates the tag against
`<Version>` in `Kongroo.Templates.csproj`, packs, and pushes to nuget.org using a
short-lived token exchanged from GitHub's OIDC token.

## One-time setup (do this after the repo is on GitHub)

These steps need your nuget.org account and the GitHub repo — they cannot be
automated from a local checkout.

1. **Create the trusted-publishing policy** at
   <https://www.nuget.org/account/trustedpublishing> → **Add policy**:
   - **Repository Owner**: `almeidajr`
   - **Repository**: `Kongroo.Templates`
   - **Workflow File**: `release.yml` *(filename only — must match exactly, case-insensitive)*
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
# 1. Bump <Version> in Kongroo.Templates.csproj (e.g. 0.1.0 -> 0.2.0)
# 2. Commit, then tag and push
git commit -am "release: 0.2.0"
git tag v0.2.0
git push origin main --tags
# release.yml runs automatically and publishes Kongroo.Templates 0.2.0 to nuget.org
```

The tag (`v0.2.0`) must match `<Version>` (`0.2.0`) or the workflow fails the
validation step before packing.

## Notes

- `--skip-duplicate` makes re-runs idempotent (re-pushing an existing version is a no-op, not an error).
- Generated repos (from `kongroo-sln` / `kongroo-nuget`) ship their own
  `release.yml` using the same OIDC pattern; each repo's packable libraries
  publish the same keyless way once its own trusted-publishing policy is created.
