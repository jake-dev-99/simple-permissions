# simple_permissions

[![CI](https://github.com/simplezen/simple-permissions/actions/workflows/ci.yml/badge.svg)](https://github.com/simplezen/simple-permissions/actions/workflows/ci.yml)

Federated permission and capability plugin for Flutter.

Provides a **typed, cross-platform capability API** for checking and requesting
device permissions. Android runtime permissions, app roles (SMS / Dialer), and
battery optimization are handled natively; iOS supports contacts, notifications,
and media library access.

## Platform Support

| Platform | Status |
| -------- | ------ |
| Android | ✅ Full (permissions, roles, battery optimization) |
| iOS | ✅ Contacts, notifications, media (images/video/audio) |
| macOS / web / Linux / Windows | No-op — all capabilities return `granted` |

## Installation

```yaml
dependencies:
  simple_permissions: ^0.3.0
```

## Quick Start

```dart
import 'package:simple_permissions_native/simple_permissions.dart';

// Initialize once at app startup
await SimplePermissions.initialize();

// High-level intention check (routes through capabilities internally)
final ready = await SimplePermissions.instance.check(Intention.texting);
if (!ready) {
  await SimplePermissions.instance.request(Intention.texting);
}

// Granular capability check
final grant = await SimplePermissions.instance.checkCapability(
  PermissionCapability.canReadContacts,
);
if (grant != PermissionGrant.granted) {
  await SimplePermissions.instance.requestCapability(
    PermissionCapability.canReadContacts,
  );
}

// Multi-capability detailed result
final result = await SimplePermissions.instance.requestDetailedCapabilities(
  Intention.texting.capabilities,
);
if (result.requiresSettings) {
  await SimplePermissions.instance.openAppSettings();
} else if (result.isFullyGranted) {
  // All permissions secured — proceed.
}
```

## API Reference

### Primary API (capability-based)

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `initialize()` | `Future<void>` | Must be called before any other method |
| `check(Intention)` | `Future<bool>` | Quick boolean — are all capabilities for the intention granted? |
| `request(Intention)` | `Future<bool>` | Request all capabilities for an intention |
| `checkCapability(PermissionCapability)` | `Future<PermissionGrant>` | Check a single capability |
| `requestCapability(PermissionCapability)` | `Future<PermissionGrant>` | Request a single capability |
| `checkDetailedCapabilities(List<PermissionCapability>)` | `Future<CapabilityResult>` | Batch check with per-capability detail |
| `requestDetailedCapabilities(List<PermissionCapability>)` | `Future<CapabilityResult>` | Batch request with per-capability detail |
| `openAppSettings()` | `Future<bool>` | Open the OS settings page for the app |

### `CapabilityResult`

Returned by `checkDetailedCapabilities` and `requestDetailedCapabilities`:

| Getter | Type | Description |
| ------ | ---- | ----------- |
| `capabilities` | `Map<PermissionCapability, PermissionGrant>` | Per-capability grant status |
| `isFullyGranted` | `bool` | All are `granted` or `notApplicable` |
| `isReady` | `bool` | Alias for `isFullyGranted` |
| `hasDenial` | `bool` | Any capability was `denied` |
| `hasPermanentDenial` | `bool` | Any capability was `permanentlyDenied` |
| `requiresSettings` | `bool` | User must go to settings to unblock |
| `denied` | `List<PermissionCapability>` | Capabilities that were denied |
| `permanentlyDenied` | `List<PermissionCapability>` | Capabilities that require settings |

### `PermissionGrant` enum

`granted` · `denied` · `permanentlyDenied` · `restricted` · `limited` · `notApplicable`

### `PermissionCapability` enum

`canSendMessages` · `canReadMessages` · `canReceiveMessages` · `canMakeCalls` ·
`canAnswerCalls` · `canReadPhoneState` · `canReadContacts` · `canWriteContacts` ·
`canPostNotifications` · `canReadMediaImages` · `canReadMediaVideo` ·
`canReadMediaAudio` · `canReadExternalStorage` ·
`canBypassBatteryOptimizations` · `canBeDefaultMessagingApp` ·
`canBeDefaultDialerApp`

### `Intention` enum

Groups capabilities by use-case:

| Intention | Capabilities |
| --------- | ------------ |
| `texting` | SMS send/receive, MMS receive, read SMS/MMS, role, battery |
| `calling` | Phone calls, phone state, answer calls, call log, dialer role |
| `contacts` | Read + write contacts |
| `device` | Read phone state |
| `fileAccess` | Media images, video, audio |
| `notifications` | Post notifications |

### Deprecated API

The following methods still work but will be removed in a future release.
See `@Deprecated` annotations in source for migration guidance.

`checkPermissions`, `requestPermissions`, `checkDetailed`, `requestDetailed`,
`isRoleHeld`, `requestRole`, `isIgnoringBatteryOptimizations`,
`requestBatteryOptimizationExemption`, `shouldShowRequestPermissionRationale`,
`shouldShowRationale`

The `PermissionResult` class is also deprecated in favour of `CapabilityResult`.

## Migration from 0.2.x → 0.3.0

```dart
// Before (0.2.x)
final result = await SimplePermissions.instance.checkPermissions(
  Intention.texting.permissions,
);
final isHeld = await SimplePermissions.instance.isRoleHeld(Intention.texting.role!);

// After (0.3.0)
final result = await SimplePermissions.instance.checkDetailedCapabilities(
  Intention.texting.capabilities,
);
// result.isFullyGranted covers permissions + role in one call
```

Key changes:

- **Capability API is primary.** `check()` and `request()` now route through
  `checkDetailedCapabilities` / `requestDetailedCapabilities` internally.
- **`CapabilityResult`** replaces `PermissionResult` — cross-platform, typed.
- **`Intention.permissions`** and **`Intention.role`** are deprecated.
  Use **`Intention.capabilities`** instead.
- All string-based methods (`checkPermissions`, `isRoleHeld`, etc.) are deprecated.
- **Battery optimization is explicit.** If your app previously used
  `isIgnoringBatteryOptimizations()`/`requestBatteryOptimizationExemption()`,
  migrate to:
  `checkCapability(PermissionCapability.canBypassBatteryOptimizations)` and
  `requestCapability(PermissionCapability.canBypassBatteryOptimizations)`.

## iOS Setup

For iOS capability requests to show system permission prompts, the host app must
include usage description keys in `ios/Runner/Info.plist`:

- Minimum iOS version: **14.0**

| Capability | Info.plist Key |
| ---------- | -------------- |
| `canReadContacts` / `canWriteContacts` | `NSContactsUsageDescription` |
| `canReadMediaImages` / `canReadMediaVideo` | `NSPhotoLibraryUsageDescription` |
| `canReadMediaAudio` | `NSMicrophoneUsageDescription` |
| `canPostNotifications` | _(none required)_ |

```xml
<key>NSContactsUsageDescription</key>
<string>This app needs access to your contacts to display conversations.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to your photo library to send and view media.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to send audio messages.</string>
```

## Notes

- Call `SimplePermissions.initialize()` before using instance methods.
- Concurrent request operations of the same type are rejected with
  `PlatformException(code: "request-in-progress")`.
- Android API-level normalization is built in:
  `READ_EXTERNAL_STORAGE` → not required on API 33+;
  `READ_MEDIA_*` / `POST_NOTIFICATIONS` → not required below API 33.
- iOS returns `PermissionGrant.notApplicable` for Android-only capabilities
  (roles, battery, SMS send/receive).
- Other unsupported platforms use the noop fallback and return `granted`.

## Architecture

```text
simple_permissions/                        ← App-facing facade
├── simple_permissions_platform_interface/  ← Abstract contract + types
├── simple_permissions_android/             ← Pigeon-based Android impl
└── simple_permissions_ios/                 ← MethodChannel-based iOS impl
```

## License

MIT © 2025 SimpleZen
