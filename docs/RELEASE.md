# Release flow

Three-branch promotion pipeline with pub.dev publishing gated on
`main`:

```
feature branch
     │  PR  ▼  (CI runs)
  develop
     │  PR  ▼  (CI runs)
  staging
     │  PR  ▼  (CI runs)
    main
     │  push to main ▼  (auto-tag bumps versions + tags commit)
     │  tag push ▼      (publish.yml runs OIDC pub.dev release)
    pub.dev
```

## Branch intent

| Branch | Role |
|---|---|
| `develop` | Default working branch. Feature branches PR here. Represents "what's shipping next, eventually." |
| `staging` | Pre-release gate. Merging `develop` -> `staging` signals "this is the shape of the next release; soaking before it hits prod." Optional pre-release pub.dev publishes can cut from here (`0.4.0-dev.1` etc). |
| `main` | Production. Merging `staging` -> `main` is the release moment. Tag pushes on `main` trigger pub.dev publishing. |

CI runs on PRs to any of the three. CD (pub.dev publishing) runs
on **tag push**, not on merge — a merge to `main` doesn't
auto-publish; tagging is the explicit release gesture.

## Cutting a release

1. Land your work on `develop` via PRs.
2. `develop` -> `staging` PR. CI runs. Merge.
3. `staging` -> `main` PR. CI runs. Merge.
4. The push to `main` triggers
   [`auto-tag.yml`](../.github/workflows/auto-tag.yml). Per
   changed package it:
   - Reads the current `pubspec.yaml` version.
   - Finds the highest existing `<package>-v<semver>` tag.
   - Picks the next version with
     `max(pubspec_version, highest_tag + 0.0.1)`. Default
     path is a patch bump from the last release; if the merge
     PR bumped the pubspec minor or major, the bump wins.
   - Rewrites the pubspec to match, commits with `[skip ci]`,
     tags, and pushes.
5. The tag push fires
   [`publish.yml`](../.github/workflows/publish.yml) which
   verifies the tag version matches `pubspec.yaml` and runs
   `dart pub publish --force`. pub.dev authenticates via OIDC
   — no long-lived credentials anywhere in the repo.

**Shipping a minor or major release** is just *"bump the
pubspec on the merge PR"*. The auto-tagger sees the pubspec is
already past its patch-bump candidate and respects the manual
intent.

## Tag patterns (one per federated package)

| Package | Tag prefix | Working dir |
|---|---|---|
| `simple_permissions_native` | `simple_permissions_native-v` | `.` (repo root) |
| `simple_permissions_platform_interface` | `simple_permissions_platform_interface-v` | `packages/simple_permissions_platform_interface` |
| `simple_permissions_android` | `simple_permissions_android-v` | `packages/simple_permissions_android` |
| `simple_permissions_ios` | `simple_permissions_ios-v` | `packages/simple_permissions_ios` |
| `simple_permissions_macos` | `simple_permissions_macos-v` | `packages/simple_permissions_macos` |
| `simple_permissions_web` | `simple_permissions_web-v` | `packages/simple_permissions_web` |

Each package's version advances independently. A single release
event can tag more than one package; tag each separately and the
matching matrix jobs run in parallel.

## One-time pub.dev setup (per package)

Each federated package has to be configured on pub.dev's
*"Automated publishing"* admin panel before the first release:

1. Visit `https://pub.dev/packages/<package>/admin`.
2. Enable **Automated publishing** -> *Publishing from GitHub Actions*.
3. Fill in:
   - **Repository**: `<owner>/simple-permissions`
   - **Tag pattern**: `<package>-v{{version}}`
   (e.g. `simple_permissions_native-v{{version}}`).
4. Save. pub.dev starts accepting OIDC-authenticated publish
   requests that match.

Without this, `dart pub publish` from the workflow errors with
`missing OIDC authorization` and the release fails cleanly — the
package is never half-published.

## Why this shape

- **CI on PR opened.** Catches breakage before merge. `push`-
  triggered CI on `develop` was removed because every landed
  change already passed the PR check; running again on merge is
  redundant spend.
- **CD on tag, not on merge.** Merges to `main` shouldn't force
  a pub.dev release — sometimes a merge is a doc fix, a revert,
  or a regression hotfix that's not ready to publish. The tag is
  the intent-to-release signal.
- **Per-package tags** instead of one monorepo-style tag
  because pub.dev's automated-publishing contract ties one tag
  pattern to one package. Sidesteps the melos/publishing-orch
  tooling we don't otherwise need.
- **OIDC (no stored tokens).** Long-lived `PUB_DEV_CREDENTIALS`
  in a GitHub secret is the old pattern; OIDC is the current
  pub.dev recommendation and leaves no credential to steal.
