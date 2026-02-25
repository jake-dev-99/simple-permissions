# simple_permissions

Android permission and role plugin for Flutter.

`simple_permissions` provides a typed, minimal API for Android runtime permissions,
role checks/requests (SMS and Dialer), and battery optimization exemption.

## Platform support

- Android: supported
- iOS/macOS/web/linux/windows: not supported (calls throw `UnsupportedError`)

## Installation

```yaml
dependencies:
  simple_permissions: ^0.2.0
```

## Usage

```dart
import 'package:simple_permissions/simple_permissions.dart';

await SimplePermissions.initialize();

final isTextingReady = await SimplePermissions.instance.check(Intention.texting);

if (!isTextingReady) {
  final granted = await SimplePermissions.instance.request(Intention.texting);
  if (!granted) {
    // Show next-step guidance to the user.
  }
}

final detailed = await SimplePermissions.instance.requestDetailed(
  Intention.texting,
);
if (detailed.requiresSettings) {
  await SimplePermissions.instance.openAppSettings();
}
```

## API

- `SimplePermissions.initialize()`
- `check(Intention intention)`
- `request(Intention intention)`
- `checkDetailed(Intention intention) -> PermissionResult`
- `requestDetailed(Intention intention) -> PermissionResult`
- `checkPermissions(List<String> permissions)`
- `requestPermissions(List<String> permissions)`
- `shouldShowRequestPermissionRationale(List<String> permissions)`
- `shouldShowRationale(Intention intention)`
- `openAppSettings()`
- `isRoleHeld(String roleId)`
- `requestRole(String roleId)`
- `isIgnoringBatteryOptimizations()`
- `requestBatteryOptimizationExemption()`

`PermissionResult` includes:
- `roleStatus`
- `permissions` (per-permission status map)
- `allPermissionsGranted`
- `isRoleGranted`
- `isFullyGranted`
- `hasPermanentDenial`
- `requiresSettings`

## Notes

- Call `SimplePermissions.initialize()` before using instance methods.
- Permission strings are Android permission IDs (for example
  `android.permission.READ_CONTACTS`).
- Concurrent request operations of the same type are rejected with
  `PlatformException(code: "request-in-progress")`.
- API-level normalization is built in for media/notification permissions:
  `READ_EXTERNAL_STORAGE` is treated as not required on API 33+, and
  `READ_MEDIA_*` / `POST_NOTIFICATIONS` are treated as not required below API 33.

## Android Test Matrix

Use the integration test matrix to validate API-level behavior explicitly.

- API 31 baseline:
  `flutter test integration_test/plugin_integration_test.dart --dart-define=ANDROID_API_LEVEL=31`
- API 33 notifications/media:
  `flutter test integration_test/plugin_integration_test.dart --dart-define=ANDROID_API_LEVEL=33`
- API 34+ media stability:
  `flutter test integration_test/plugin_integration_test.dart --dart-define=ANDROID_API_LEVEL=34`

Matrix expectations:
- API 31: `READ_MEDIA_*` and `POST_NOTIFICATIONS` normalize to granted.
- API 33: `READ_EXTERNAL_STORAGE` normalizes to granted (not required).
- API 34+: file/media checks remain deterministic and include compatibility keys.
