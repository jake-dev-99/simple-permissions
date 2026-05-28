# Release flow

`main`-only with tag-driven pub.dev publishing, per the Simple Zen
Toolchain Architecture SOP.

```
feature branch
     │  PR  ▼  (CI runs)
    main
     │  push to main ▼  (auto-tag bumps versions + tags commit)
     │  tag push ▼      (deploy.yml runs OIDC pub.dev release)
    pub.dev
```

## Branch intent

| Branch | Role |
|---|---|
| `main` | Production. Feature branches PR directly here. The push to `main` triggers auto-tagging; the tag push triggers the pub.dev publish. |

`develop` / `staging` branches were retired — solo-dev ops doesn't justify
a multi-branch promotion pipeline. CI runs on every PR; CD runs on **tag
push**, not on the merge.

## Cutting a release

1. Land your work on `main` via a PR. CI runs; merge.
2. The push to `main` triggers
   [`auto-tag.yml`](../.github/workflows/auto-tag.yml). Per changed
   package it:
   - Reads the current `pubspec.yaml` version.
   - Finds the highest existing `<package>-v<semver>` tag.
   - Picks the next version with
     `max(pubspec_version, highest_tag + 0.0.1)`. Default path is a
     patch bump from the last release; if the merge PR bumped the
     pubspec minor or major, the bump wins.
   - Rewrites the pubspec to match, commits with `[skip ci]`, tags,
     and pushes.
3. The tag push fires
   [`deploy.yml`](../.github/workflows/deploy.yml) which verifies the
   tag version matches `pubspec.yaml` and runs `dart pub publish
   --force`. pub.dev authenticates via OIDC — no long-lived
   credentials anywhere in the repo.

**Shipping a minor or major release** is just *"bump the pubspec on
the merge PR"*. The auto-tagger sees the pubspec is already past its
patch-bump candidate and respects the manual intent.

## Tag patterns (one per federated package)

| Package | Tag prefix | Working dir |
|---|---|---|
| `simple_permissions_native` | `simple_permissions_native-v` | `.` (repo root) |
| `simple_permissions_platform_interface` | `simple_permissions_platform_interface-v` | `packages/simple_permissions_platform_interface` |
| `simple_permissions_android` | `simple_permissions_android-v` | `packages/simple_permissions_android` |
| `simple_permissions_ios` | `simple_permissions_ios-v` | `packages/simple_permissions_ios` |
| `simple_permissions_macos` | `simple_permissions_macos-v` | `packages/simple_permissions_macos` |
| `simple_permissions_web` | `simple_permissions_web-v` | `packages/simple_permissions_web` |

Each package's version advances independently. A single release event
can tag more than one package; tag each separately and the matching
matrix jobs run in parallel.

## CI secrets & rulesets

`auto-tag.yml` has three external dependencies that aren't visible from
reading the workflow file. If any drifts, auto-tag silently starts
failing with `GH013` rule-violation rejections on every merge to `main`.

1. **Deploy key (write)**. Repo Settings → Deploy keys has an entry
   titled "auto-tag workflow (write)" with *Allow write access*
   checked. This is the public half of the ed25519 pair used by the
   workflow's SSH push.
2. **`AUTO_TAG_DEPLOY_KEY` secret**. Repo Settings → Secrets → Actions
   holds the private half of the same key. The workflow's checkout
   step loads it into ssh-agent via `ssh-key:`.
3. **`main` ruleset bypass**. Repo Settings → Rules → the `main`
   ruleset has **Deploy keys** in its Bypass list, which exempts
   deploy-key-authenticated pushes from the PR-required and
   signed-commits rules.

Why all three: `main` requires PRs + signed commits for every push,
but the workflow needs to commit pubspec bumps and push tags after a
release merge. `github-actions[bot]` (the identity behind the default
`GITHUB_TOKEN`) isn't a bypass-able actor on GitHub's picker. Deploy
keys are, so we push as the key instead.

To rotate: generate a new ed25519 pair, upload the public half as a
new deploy key with write access (delete the old entry), update the
`AUTO_TAG_DEPLOY_KEY` secret with the new private half. The bypass
list entry stays — it's scoped to "any deploy key", not a specific one.

## One-time pub.dev setup (per package)

Each federated package has to be configured on pub.dev's *"Automated
publishing"* admin panel before the first release:

1. Visit `https://pub.dev/packages/<package>/admin`.
2. Enable **Automated publishing** → *Publishing from GitHub Actions*.
3. Fill in:
   - **Repository**: `<owner>/simple-permissions`
   - **Tag pattern**: `<package>-v{{version}}`
   (e.g. `simple_permissions_native-v{{version}}`).
4. Save. pub.dev starts accepting OIDC-authenticated publish requests
   that match.

Without this, `dart pub publish` from the workflow errors with
`missing OIDC authorization` and the release fails cleanly — the
package is never half-published.

## Why this shape

- **CI on PR opened.** Catches breakage before merge. `push`-triggered
  CI was dropped because every landed change already passed the PR
  check; running again on merge is redundant spend.
- **CD on tag, not on merge.** Merges to `main` shouldn't force a
  pub.dev release — sometimes a merge is a doc fix, a revert, or a
  regression hotfix that's not ready to publish. The tag is the
  intent-to-release signal.
- **Per-package tags** instead of one monorepo-style tag because
  pub.dev's automated-publishing contract ties one tag pattern to
  one package. Sidesteps the melos/publishing-orch tooling we don't
  otherwise need.
- **OIDC (no stored tokens).** Long-lived `PUB_DEV_CREDENTIALS` in a
  GitHub secret is the old pattern; OIDC is the current pub.dev
  recommendation and leaves no credential to steal.
