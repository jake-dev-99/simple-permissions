# simple_permissions_native

[![CI](https://github.com/simplezen/simple-permissions/actions/workflows/ci.yml/badge.svg)](https://github.com/simplezen/simple-permissions/actions/workflows/ci.yml)

Federated Flutter permission plugin with a typed, sealed-class API and Pigeon-backed native implementations for Android, iOS, and macOS.

## Installation

```yaml
dependencies:
  simple_permissions_native: ^1.1.0
```

## Quick start

```dart
import 'package:simple_permissions_native/simple_permissions_native.dart';

Future<void> bootstrapPermissions() async {
  await SimplePermissionsNative.initialize();

  final grant = await SimplePermissionsNative.instance.check(
    const ReadContacts(),
  );

  if (grant != PermissionGrant.granted) {
    await SimplePermissionsNative.instance.request(const ReadContacts());
  }
}
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

## PermissionResult semantics

`PermissionResult.isFullyGranted` treats these grants as satisfied:

- `granted`
- `limited`
- `provisional`

`requiresSettings` is `true` when at least one permission is `permanentlyDenied`.

`hasUnsupported` is `true` when any permission resolves to `notApplicable` or `notAvailable`.

## Intentions

Built-in `Intention` presets group common runtime permissions, but role takeovers are explicit:

- `Intention.texting` and `Intention.calling` include runtime permissions only
- `Intention.defaultSmsRole` and `Intention.defaultDialerRole` request roles explicitly
- `Intention.textingWithDefaultSmsRole` and `Intention.callingWithDefaultDialerRole` opt into composite takeover flows

This keeps product-level app-role decisions out of the default convenience presets.

## Platform support

| Platform | Support |
| --- | --- |
| Android | Runtime permissions, roles, and system-setting flows |
| iOS | Pigeon-backed Swift handlers for framework permission APIs |
| macOS | Pigeon-backed Swift handlers for framework permission APIs |
| web / Linux / Windows | Explicit unsupported fallback returning `notApplicable` |

## Host app setup

Add the usage-description keys your app actually needs:

- `NSContactsUsageDescription`
- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSCalendarsUsageDescription`
- `NSRemindersUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSBluetoothAlwaysUsageDescription`
- `NSUserTrackingUsageDescription`

Health permissions also require the appropriate HealthKit usage strings and entitlements. On macOS, camera, microphone, contacts, and location also require matching sandbox entitlements in the host app.

## Architecture

```text
simple_permissions_native/
├── lib/simple_permissions_native.dart          <- App-facing facade
├── packages/simple_permissions_platform_interface/
├── packages/simple_permissions_android/        <- Pigeon + Kotlin handlers
├── packages/simple_permissions_ios/            <- Pigeon + Swift handlers
└── packages/simple_permissions_macos/          <- Pigeon + Swift handlers
```

## Validation

The repository includes:

- Dart/package unit tests across the federated packages
- Apple build validation for the example app
- Example smoke tests for contacts, camera, microphone, and fine location on Apple targets

## License

MIT © 2025 SimpleZen
