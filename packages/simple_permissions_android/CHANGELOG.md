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

