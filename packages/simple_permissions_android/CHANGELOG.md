## 1.3.2

- (no commits in packages/simple_permissions_android since simple_permissions_android-v1.3.1)
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

- Consolidated Kotlin system-settings boilerplate into data-driven dispatch.
- Consolidated Dart `SystemSettingHandler` switch duplication via enum methods.
- Removed duplicate background-location foreground check from `RuntimePermissionHandler`.
- Added Android rationale classification documentation.

## 1.1.0

- Added support for additional Android permission types:
  - `BodySensorsBackground`
  - `ReadVoicemail`
  - `AddVoicemail`
  - `UwbRanging`
  - `AcceptHandover`
- Added background location sequencing enforcement on API 30+.

## 1.0.0

- Initial stable Android implementation for the federated plugin.
- Added typed permission check/request APIs through Pigeon host bridge.