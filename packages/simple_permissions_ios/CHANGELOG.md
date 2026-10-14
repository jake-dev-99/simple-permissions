## 1.3.4

- Updates the minimum supported SDK version to Flutter 3.44/Dart 3.12 (UNFY-173).
- Adds Swift Package Manager support; CocoaPods remains supported (UNFY-173).

- chore(UNFY-173): record the migration in changelogs; build the example
- chore(UNFY-173): adopt Swift Package Manager and built-in Kotlin
- fix(UNFY-123): keep Flutter analyzer migration source clean
- chore(release): cut 6 tags (patch bump)
- chore(release): cut 6 tags (patch bump)
- chore(release): reset versions to align with pub.dev
- chore(release): align federated packages on coordinated 1.8.0
- refactor(apple): consolidate handler mapping logic into PermissionGuards
- docs + chore: re-frame PermissionGuards as developer-facing; bump 1.8.0
- feat(ios): add .health(HKObjectType) case to ApplePermissionKind
- feat(apple): async requestAuthorization / requireAuthorizationGranted
- feat(apple): Swift PermissionGrant enum + authorizationStatus(for:)
- chore: bump to 1.7.0 + CHANGELOG entry
- feat(ios): PermissionGuards Swift parity with Kotlin assertions
- chore(lints): elevate silent-bug lints to errors across packages
- Merge pull request #13 from jake-dev-99/fix/ios-motion-cmerror-literal
- fix(ios): make mapStatus static to avoid self-capture in closure
- Merge pull request #11 from jake-dev-99/ci/dispatch-publish-from-autotag
- fix(ios): use CMAuthorizationStatus instead of CMError cases
- Require simple_permissions_platform_interface ^1.3.4.

## 1.3.3

- (no commits in packages/simple_permissions_ios since simple_permissions_ios-v1.3.2)
## 1.3.2

- (no commits in packages/simple_permissions_ios since simple_permissions_ios-v1.3.1)
## 1.3.1

### Reset to align with pub.dev's published series

This package on pub.dev is at 1.3.0. Local git tags 1.8.0,
1.8.1 (and 1.3.1 on `_android`) were authored ahead of the next
publish but never reached pub.dev. Orphan tags deleted from
origin and the version reset to the smallest patch above the
last-published version (1.3.0 → 1.3.1).

Cross-package constraint on `simple_permissions_platform_interface`
lowered from `^1.8.0` to `^1.3.0` to match the published series.

The 1.8.0 work described below is not lost — it lives in source
and will surface in published form through subsequent bumps.
Entry kept for archival reference.

## 1.8.0

- Coordinated release: aligned all federated packages on 1.8.0 to match
  the `simple_permissions_native` facade. No source changes — version
  consolidation only. Fills in the gap from the previously-unpublished
  versions (1.3 — 1.7) where the facade evolved independently of the
  platform packages.
- All cross-package constraints bumped to `^1.8.0`.

## 1.2.0

- Split native iOS permission handlers into domain files with a centralized registry.
- Added Apple example build and smoke-test coverage for the federated plugin.
- Added iOS/macOS handler sync documentation.

## 1.1.0

- Added location accuracy status bridge support.
- Synced plugin and podspec metadata to `1.1.0`.
- Continued Pigeon-based typed permission bridge coverage for iOS handlers.

## 1.0.0

- Initial stable iOS implementation for the federated plugin.
- Added Swift authorization handlers wired through Pigeon host APIs.