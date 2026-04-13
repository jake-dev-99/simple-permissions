## 1.2.0

- Added Apple example targets, Apple build validation, and Apple smoke-test coverage in CI.
- Refactored iOS and macOS native handlers into domain-specific Swift files with centralized registries.
- Split role-acquisition `Intention` presets from the default `texting` and `calling` runtime-permission presets.
- Consolidated Android Kotlin system-settings boilerplate into a data-driven dispatch pattern.
- Consolidated Dart `SystemSettingHandler` switch duplication via `SystemSettingType` enum methods.
- Removed duplicate background-location foreground check from `RuntimePermissionHandler` (orchestrator owns this logic).
- Expanded README with platform setup guides, `PermissionGrant` state table, `Intention` reference, and usage examples.
- Improved example app with Intention-based flows, batch requests, and denied-state handling.
- Made `Intention` const-constructible from user code (removed `UnmodifiableListView` wrapping).
- Added symmetric Kotlin test coverage for all system-setting request flows (overlay, install packages, schedule exact alarms).
- Added web platform support (`simple_permissions_web`) with browser Permissions API for camera, microphone, geolocation, and notifications.

## 1.1.0

- Added location accuracy API:
  - `checkLocationAccuracy()`
  - `LocationAccuracyStatus` (`precise`, `reduced`, `none`, `notApplicable`, `notAvailable`)
- Enforced Android background-location sequencing on API 30+:
  - `BackgroundLocation` requests now require prior foreground location grant.
  - If requested first, the plugin returns `PermissionGrant.denied` and does not invoke runtime request.
- Added Android permission types:
  - `BodySensorsBackground`
  - `ReadVoicemail`
  - `AddVoicemail`
  - `UwbRanging`
  - `AcceptHandover`

## 1.0.0

- Initial release of `simple_permissions_native`.
- Introduced federated plugin structure with:
  - `simple_permissions_platform_interface`
  - `simple_permissions_android`
  - `simple_permissions_ios`
- Added capability-based permission APIs for cross-platform checks and requests.
- Added detailed permission result modeling for richer status reporting.
- Included iOS privacy manifest support for App Store compliance.
