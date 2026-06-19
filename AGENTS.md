# AGENTS.md — working in `simple-permissions`

Canonical guide for any agent or contributor in this repo (Claude Code
reads it via [`CLAUDE.md`](CLAUDE.md), which `@`-imports this file).
Keep it short and true.

## What this is

**`simple_permissions_native`** — a **federated Flutter plugin** for unified
runtime permission handling: runtime permissions, app roles (SMS, Dialer),
and battery-optimization exemptions. It is a **Simple Zen Plugin** (a
library/dependency, not a consumer app) — consumed by **Unify Messages+**
as a path/pub dependency. Governance: the Simple Zen SOP family in Notion
(Documentation Standard, Code Quality Standards, Toolchain Architecture).
As a `Type = Plugin`, the App-only gates (Linear project, Figma, consumer
Category, GTM/brand) do **not** apply; code-quality, semver/API-stability,
tests, and docs do.

## Layout (federated)

```
.                              # root package: simple_permissions_native (facade)
packages/
  simple_permissions_platform_interface   # the contract — the load-bearing API
  simple_permissions_android
  simple_permissions_ios
  simple_permissions_macos
  simple_permissions_web
```

The **platform interface is the contract.** Every platform package
implements it; the facade dispatches to them.

## Build · test · verify

SDK constraints live in each package's `pubspec.yaml` (`environment:`
block) — that's the source of truth; this doc does not pin specific
versions so the two can't drift. Mirror CI
(`.github/workflows/verify.yml`), which runs a per-package matrix.
Before any push:

```sh
flutter pub get
flutter analyze --no-fatal-warnings
flutter test
flutter pub publish --dry-run     # packaging must stay publishable
```

Run them in each package you touched (the facade + the platform impls the
change affects), as CI does.

## Conventions that have teeth

- **The platform-interface contract is versioned.** A breaking change to
  `simple_permissions_platform_interface` is a **major** bump, and every
  platform implementation moves with it in the same change — no
  half-migrated federation.
- **Keep the federation in sync.** A new method on the interface lands in
  every platform package (or throws `UnimplementedError` deliberately,
  documented), never silently missing.
- `analysis_options.yaml` is the lint baseline; analyze must be clean
  (`--no-fatal-warnings` matches CI).
- See `docs/` for the deeper design notes (`ENUMS_TO_SEALED.md`,
  `INTEGRATION_GUIDE.md`, `PROJECT_WHITEPAPER.md`).

## Git workflow

`main`-only with git tags for releases (no `develop`/`staging`). One
short-lived branch per work item; PRs target `main`. Releases are cut via
`.github/workflows/release.yml`; see [`docs/RELEASE.md`](docs/RELEASE.md).

## What NOT to do (binding rulings)

- **Don't break the platform-interface API without a major version bump** —
  downstream (Unify Messages+) and pub.dev consumers depend on it.
- **Don't add a method to the interface without implementing it across all
  platform packages** in the same change.
- **Don't push without the verify gate green** (`pub get` → `analyze
  --no-fatal-warnings` → `test` → `pub publish --dry-run`). CI is a
  backstop, not discovery.
- **Don't commit secrets** or platform credentials.
- **Don't add app-level concerns** here (GTM, brand, product roadmap) —
  this is a library.
