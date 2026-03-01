# simple_permissions_native

[![CI](https://github.com/simplezen/simple-permissions/actions/workflows/ci.yml/badge.svg)](https://github.com/simplezen/simple-permissions/actions/workflows/ci.yml)

Federated Flutter permission plugin with a typed API built on sealed `Permission` classes.

## Installation

```yaml
dependencies:
  simple_permissions_native: ^1.1.0
```

## Quick Start

```dart
import 'package:simple_permissions_native/simple_permissions_native.dart';

Future<void> bootstrapPermissions() async {
  await SimplePermissionsNative.initialize();

  final contactsGrant = await SimplePermissionsNative.instance.check(
    const ReadContacts(),
  );

  if (contactsGrant != PermissionGrant.granted) {
    await SimplePermissionsNative.instance.request(const ReadContacts());
  }
}
```

## Batch + Intention APIs

```dart
final result = await SimplePermissionsNative.instance.requestAll([
  const ReadContacts(),
  const WriteContacts(),
  const PostNotifications(),
]);

if (result.requiresSettings) {
  await SimplePermissionsNative.instance.openAppSettings();
}

final textingReady = await SimplePermissionsNative.instance.checkIntention(
  Intention.texting,
);
```

## Public API

- `SimplePermissionsNative.initialize()`
- `check(Permission)` / `request(Permission)`
- `checkAll(List<Permission>)` / `requestAll(List<Permission>)`
- `checkIntention(Intention)` / `requestIntention(Intention)`
- `checkIntentionDetailed(Intention)` / `requestIntentionDetailed(Intention)`
- `isSupported(Permission)`
- `openAppSettings()`
- `checkLocationAccuracy()`

## `PermissionResult` semantics

`PermissionResult.isFullyGranted` treats these grants as satisfied:

- `granted`
- `limited`
- `provisional`
- `notApplicable`
- `notAvailable`

`requiresSettings` is true when at least one permission is `permanentlyDenied`.

## Platform Support

| Platform | Support |
| --- | --- |
| Android | Runtime permissions, roles, and system-setting flows |
| iOS | Framework-backed permission handling via Pigeon |
| macOS | Framework-backed permission handling via Pigeon |
| web / Linux / Windows | No-op implementation (returns `granted`) |

## iOS / macOS host app setup

Add matching usage descriptions in host app `Info.plist` for any permissions you request.

Common keys:

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSContactsUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSCalendarsUsageDescription`
- `NSRemindersUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSBluetoothAlwaysUsageDescription`
- `NSUserTrackingUsageDescription`
- Health permissions require appropriate `HealthKit` usage strings/entitlements.

## Architecture

```text
simple_permissions_native/                    <- App-facing facade
├── packages/simple_permissions_platform_interface/
├── packages/simple_permissions_android/      <- Pigeon + Kotlin
├── packages/simple_permissions_ios/          <- Pigeon + Swift
└── packages/simple_permissions_macos/        <- Pigeon + Swift
```

## License

MIT © 2025 SimpleZen
