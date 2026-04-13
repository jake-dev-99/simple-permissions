# simple_permissions_native

[![CI](https://github.com/simplezen/simple-permissions/actions/workflows/ci.yml/badge.svg)](https://github.com/simplezen/simple-permissions/actions/workflows/ci.yml)

A federated Flutter permission plugin with a **typed, sealed-class API**. Every permission is a Dart type — no stringly-typed lookups, no magic enums. Pattern-match on results, batch requests in a single call, and express features as Intentions instead of raw permission lists.

Backed by Pigeon-generated native bridges for Android (Kotlin), iOS (Swift), and macOS (Swift).

## Installation

```yaml
dependencies:
  simple_permissions_native: ^1.2.0
```

## Quick start

```dart
import 'package:simple_permissions_native/simple_permissions_native.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SimplePermissionsNative.initialize();
  runApp(const MyApp());
}
```

### Check and request a single permission

```dart
final perms = SimplePermissionsNative.instance;

final grant = await perms.check(const CameraAccess());
if (grant != PermissionGrant.granted) {
  final result = await perms.request(const CameraAccess());
  if (result == PermissionGrant.permanentlyDenied) {
    // User selected "Don't allow" — direct them to Settings
    await perms.openAppSettings();
  }
}
```

### Batch-request multiple permissions

```dart
final result = await perms.requestAll([
  const CameraAccess(),
  const RecordAudio(),
  const FineLocation(),
]);

if (result.isFullyGranted) {
  startVideoCall();
} else if (result.requiresSettings) {
  showSettingsPrompt(result.permanentlyDenied);
}
```

### Use Intentions for feature-level requests

Instead of listing individual permissions, express what the app **intends to do**:

```dart
// Request everything needed for SMS messaging
final ok = await perms.requestIntention(Intention.texting);

// Or get detailed results
final result = await perms.requestIntentionDetailed(Intention.contacts);
if (result.hasDenial) {
  handleDenied(result.denied);
}
```

Compose custom Intentions:

```dart
final videoCall = Intention.combine('video_call', [
  Intention.camera,
  Intention.microphone,
  Intention.location,
]);
```

### Version-aware permissions

Android splits storage permissions at API 33 and Bluetooth at API 31. `VersionedPermission` resolves this automatically:

```dart
// Resolves to ReadMediaImages on API 33+, ReadExternalStorage on older devices
final result = await perms.request(VersionedPermission.images());
```

## API reference

| Method | Returns | Description |
|--------|---------|-------------|
| `initialize()` | `Future<void>` | Required before any other call |
| `check(Permission)` | `Future<PermissionGrant>` | Current grant state (no prompt) |
| `request(Permission)` | `Future<PermissionGrant>` | Request with system dialog |
| `checkAll(List<Permission>)` | `Future<PermissionResult>` | Batch check |
| `requestAll(List<Permission>)` | `Future<PermissionResult>` | Batch request (optimized on Android) |
| `checkIntention(Intention)` | `Future<bool>` | All permissions in intention granted? |
| `requestIntention(Intention)` | `Future<bool>` | Request all, return success/failure |
| `checkIntentionDetailed(Intention)` | `Future<PermissionResult>` | Intention with per-permission results |
| `requestIntentionDetailed(Intention)` | `Future<PermissionResult>` | Request intention with details |
| `isSupported(Permission)` | `Future<bool>` | Does this permission exist on this platform/OS version? |
| `openAppSettings()` | `Future<bool>` | Open system settings for this app |
| `checkLocationAccuracy()` | `Future<LocationAccuracyStatus>` | GPS precision level |

## PermissionGrant states

| State | Meaning | What to do |
|-------|---------|------------|
| `granted` | User approved | Proceed |
| `denied` | User denied (can ask again) | Show rationale, then re-request |
| `permanentlyDenied` | "Don't ask again" selected | Call `openAppSettings()` |
| `restricted` | OS-level restriction (parental controls, MDM) | Inform user; cannot be changed |
| `limited` | Partial access (e.g., iOS limited photo library) | Usable — `isFullyGranted` treats this as satisfied |
| `provisional` | iOS provisional notifications (delivers quietly) | Usable — `isFullyGranted` treats this as satisfied |
| `notApplicable` | Permission doesn't exist on this platform | Hide the feature or skip |
| `notAvailable` | Permission exists but not on this OS version | Hide or use fallback |

## Intentions

Built-in presets group common runtime permissions. Role takeovers are explicit:

| Intention | Permissions |
|-----------|------------|
| `Intention.texting` | SendSms, ReadSms, ReceiveSms, ReceiveMms, ReceiveWapPush |
| `Intention.calling` | ReadPhoneState, ReadPhoneNumbers, MakeCalls, AnswerCalls |
| `Intention.contacts` | ReadContacts, WriteContacts |
| `Intention.camera` | CameraAccess |
| `Intention.microphone` | RecordAudio |
| `Intention.location` | FineLocation, CoarseLocation |
| `Intention.notifications` | PostNotifications |
| `Intention.mediaImages` | VersionedPermission.images() |
| `Intention.mediaVideo` | VersionedPermission.video() |
| `Intention.mediaAudio` | VersionedPermission.audio() |
| `Intention.mediaVisual` | images + video combined |
| `Intention.defaultSmsRole` | DefaultSmsApp (Android role) |
| `Intention.defaultDialerRole` | DefaultDialerApp (Android role) |

`Intention.textingWithDefaultSmsRole` and `Intention.callingWithDefaultDialerRole` combine runtime permissions with role requests.

## Platform support

| Platform | Support |
|----------|---------|
| Android | Runtime permissions, app roles, system-setting intents |
| iOS | Framework permission APIs (22 permissions) |
| macOS | Framework permission APIs (13 permissions) |
| Web | Camera, microphone, geolocation, notifications via browser Permissions API |
| Linux / Windows | Returns `notApplicable` (graceful no-op) |

## Host app setup

### iOS — Info.plist

Add only the usage-description keys your app needs. The App Store will reject builds that include unused keys.

| Key | Required for |
|-----|-------------|
| `NSContactsUsageDescription` | ReadContacts, WriteContacts |
| `NSCameraUsageDescription` | CameraAccess |
| `NSMicrophoneUsageDescription` | RecordAudio |
| `NSLocationWhenInUseUsageDescription` | FineLocation, CoarseLocation |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | BackgroundLocation |
| `NSPhotoLibraryUsageDescription` | ReadMediaImages, ReadMediaVideo |
| `NSCalendarsUsageDescription` | ReadCalendar, WriteCalendar |
| `NSRemindersUsageDescription` | ReadReminders, WriteReminders |
| `NSSpeechRecognitionUsageDescription` | SpeechRecognition |
| `NSBluetoothAlwaysUsageDescription` | BluetoothConnect, BluetoothScan, BluetoothAdvertise |
| `NSMotionUsageDescription` | BodySensors, ActivityRecognition |
| `NSUserTrackingUsageDescription` | AppTrackingTransparency |
| `NSHealthShareUsageDescription` | HealthAccess |
| `NSHealthUpdateUsageDescription` | HealthAccess |

### macOS — Entitlements

macOS sandboxed apps require matching entitlements in addition to Info.plist keys:

```xml
<!-- Example: enable camera + contacts in *.entitlements -->
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.personal-information.addressbook</key>
<true/>
```

### Android — AndroidManifest.xml

Declare permissions in `android/app/src/main/AndroidManifest.xml`. Only include what your app uses.

```xml
<!-- Common permissions -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.WRITE_CONTACTS" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Storage: use both for backward compatibility -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

<!-- Notifications (API 33+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Bluetooth -->
<uses-permission android:name="android.permission.BLUETOOTH"
    android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
    android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
```

See the full list of Android permission strings in the [Android developer docs](https://developer.android.com/reference/android/Manifest.permission).

## Architecture

```text
simple_permissions_native/
├── lib/simple_permissions_native.dart          <- App-facing facade
├── packages/simple_permissions_platform_interface/
│   └── Permission sealed classes, PermissionGrant, PermissionResult, Intention
├── packages/simple_permissions_android/        <- Pigeon + Kotlin handlers
├── packages/simple_permissions_ios/            <- Pigeon + Swift handlers
├── packages/simple_permissions_macos/          <- Pigeon + Swift handlers
└── packages/simple_permissions_web/            <- Browser Permissions API
```

## License

MIT © 2025 SimpleZen
