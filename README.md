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

## Native Kotlin helpers for sibling plugins

Plugin authors whose Android code needs to **check** (read-only) whether a
runtime permission is granted or whether the app holds a default-app role can
import `PermissionGuards` from `simple_permissions_android` instead of
reaching for `ContextCompat.checkSelfPermission(...)` / `RoleManager.isRoleHeld(...)`
directly.

```kotlin
import io.simplezen.simple_permissions_android.PermissionGuards
import android.app.role.RoleManager
import android.Manifest

// Single permission
if (!PermissionGuards.isPermissionGranted(
        context, Manifest.permission.READ_SMS)) {
  return emptyList()  // silent-fail path: caller must request via Dart API
}

// Batch precondition
if (!PermissionGuards.areAllPermissionsGranted(
        context,
        listOf(Manifest.permission.READ_SMS, Manifest.permission.SEND_SMS))) {
  return
}

// Default-app role
if (!PermissionGuards.isRoleHeld(context, RoleManager.ROLE_SMS)) {
  // Read-only; to request the role, call
  // SimplePermissionsNative.instance.request(DefaultSmsApp()) from Dart.
}
```

### Gradle wiring — the honest version

A Flutter pub dep on `simple_permissions_native` is **not** enough — Flutter's
plugin system wires plugins into the final app classpath but not into each
other's compile classpaths. That alone is already a friction point, but it
turns out the simpler fix doesn't work either: a cross-repo
`implementation(project(":simple_permissions_android"))` fails to resolve
because `:simple_permissions_android` isn't a project of the consuming
plugin's build — Flutter only creates that project path inside the **final
app's** `settings.gradle`, not inside sibling plugins' builds.

Practical paths when a sibling plugin's Kotlin code wants these helpers:

1. **Same-repo plugins.** If the consuming plugin lives in the same repo as
   `simple_permissions_android` (or at least the same Gradle build),
   `implementation(project(":simple_permissions_android"))` works because
   Gradle knows the project. This is the cheapest option.

2. **Composite build (`includeBuild`).** The consuming plugin's
   `settings.gradle` declares `includeBuild("/path/to/simple-permissions/
   packages/simple_permissions_android/android")` with a dependency
   substitution. Works for local path-dep workflows but drags the
   configuration requirement down into every consuming plugin and into the
   final app.

3. **Maven publication.** `simple_permissions_android` publishes a real AAR
   (GitHub Packages or a private Maven). Sibling plugins consume via
   coordinates. Clean but needs CI plumbing.

4. **Just use Android primitives.** `ContextCompat.checkSelfPermission(...)`
   inside a sibling plugin's own Kotlin is a legitimate access-state check —
   the plugin isn't *requesting* anything, just reading the OS-level grant
   state. Rule 2 (*"access state goes through simple-permissions"*) is
   upheld at the **Dart API boundary** (request flows, observation,
   permission types) even when the underlying native check is primitive.

Until one of (1)–(3) is set up, **path 4 is fine**. `PermissionGuards`
remains valuable for the same-repo case + as a documentation signal, but
sibling plugins in separate repos (simple-sms, simple-telephony,
simple-query) will continue to use `ContextCompat.checkSelfPermission(...)`
directly.

### No request-side helpers

`PermissionGuards` deliberately does not expose a "request permission"
equivalent. Request flows surface UI and route through activity bindings —
they belong behind the Dart API (`SimplePermissionsNative.instance.request(...)`)
so the prompt is scoped by the user's consent flow, not a random native call
site.

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
