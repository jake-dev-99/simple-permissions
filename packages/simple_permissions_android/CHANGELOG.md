## 1.3.0

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