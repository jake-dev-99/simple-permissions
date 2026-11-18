
# Project Plan: simple-permissions v2 — Scalable Cross-Platform Permissions

## Scope Summary

| Dimension | Current (v1) | Target (v2) |
|-----------|-------------|-------------|
| Permission types | 16 enum values | ~80+ sealed class variants (expandable without interface changes) |
| Android | Pigeon + switch-case mapping | Handler registry with version-aware resolution |
| iOS | Partial (4 domains) | Full (12+ domains) |
| macOS / Windows / Web | None | macOS real, others stub-aware |
| Version awareness | 4 hardcoded SDK checks in Kotlin | Per-handler `minSdk`/`maxSdk` + `VersionedPermission` auto-resolution |
| API surface | 10 methods on platform interface (7 Android-specific) | 4 methods (check, request, isSupported, openAppSettings) |
| Consuming app migration | Uses low-level string API directly | Uses `Permission` sealed classes + `Intention` |

## Critical Constraint

The consuming app (`simple-messages`) currently uses the **low-level string-based API** exclusively:
- `checkPermissions(List<String>)` — 3 call sites
- `requestPermissions(List<String>)` — 1 call site
- `isRoleHeld(String)` — 2 call sites
- `requestRole(String)` — 1 call site
- `Intention` / `PermissionCapability` / `CapabilityResult` — **zero** active call sites

It also has its own `AppPermissions` class that duplicates version-aware permission mapping (the `_isAndroid13OrAbove` heuristic in app_permissions.dart). This means the consuming app already works around limitations of v1 — the migration to v2 should **absorb** `AppPermissions`'s logic into the plugin and simplify the consuming app, not just swap API shapes.

---

## Phase 1: Permission Model Redesign (platform_interface)

**Goal**: Replace the `PermissionCapability` enum with the sealed class hierarchy. This is the foundation — everything depends on it.

**Package**: `simple_permissions_platform_interface`

### 1.1 — Create the `Permission` sealed class hierarchy

Create one file per domain under `lib/src/permissions/`:

| File | Sealed base | Concrete classes |
|------|------------|-----------------|
| `permission.dart` | `Permission` (root sealed class) | — |
| `camera.dart` | `CameraPermission` | `CameraAccess` |
| `location.dart` | `LocationPermission` | `CoarseLocation`, `FineLocation`, `BackgroundLocation` |
| `contacts.dart` | `ContactsPermission` | `ReadContacts`, `WriteContacts` |
| `storage.dart` | `StoragePermission` | `ReadExternalStorage`, `ReadMediaImages`, `ReadMediaVideo`, `ReadMediaAudio`, `ReadMediaVisualUserSelected` |
| `phone.dart` | `PhonePermission` | `ReadPhoneState`, `ReadPhoneNumbers`, `MakeCalls`, `AnswerCalls`, `ManageOwnCalls`, `ReadCallLog`, `WriteCallLog` |
| `messaging.dart` | `MessagingPermission` | `SendSms`, `ReadSms`, `ReceiveSms`, `ReceiveMms`, `ReceiveWapPush` |
| `bluetooth.dart` | `BluetoothPermission` | `BluetoothConnect`, `BluetoothScan`, `BluetoothAdvertise`, `BluetoothLegacy`, `BluetoothAdminLegacy` |
| `calendar.dart` | `CalendarPermission` | `ReadCalendar`, `WriteCalendar` |
| `notification.dart` | `NotificationPermission` | `PostNotifications` |
| `microphone.dart` | `MicrophonePermission` | `RecordAudio` |
| `sensor.dart` | `SensorPermission` | `BodySensors`, `ActivityRecognition` |
| `system.dart` | `SystemPermission` | `BatteryOptimizationExemption`, `ScheduleExactAlarm`, `RequestInstallPackages`, `SystemAlertWindow` |
| `role.dart` | `AppRole` | `DefaultSmsApp`, `DefaultDialerApp`, `DefaultBrowserApp`, `DefaultAssistantApp` |
| `wifi.dart` | `WifiPermission` | `NearbyWifiDevices` |
| `tracking.dart` | `TrackingPermission` | `AppTrackingTransparency` (iOS-specific concept, `notApplicable` elsewhere) |
| `health.dart` | `HealthPermission` | `ReadHealth`, `WriteHealth` (iOS HealthKit / Android Health Connect) |

Each concrete class has:
```dart
class ReadMediaImages extends StoragePermission {
  const ReadMediaImages();
  @override String get identifier => 'read_media_images';
}
```

### 1.2 — Create `VersionedPermission`

File: `lib/src/versioned_permission.dart`

This is the developer-facing "give me the right permission for the running OS" concept. Named factory constructors for common version-split scenarios:

```dart
VersionedPermission.images()     // READ_MEDIA_IMAGES → READ_EXTERNAL_STORAGE
VersionedPermission.video()      // READ_MEDIA_VIDEO → READ_EXTERNAL_STORAGE
VersionedPermission.audio()      // READ_MEDIA_AUDIO → READ_EXTERNAL_STORAGE
VersionedPermission.bluetooth()  // BLUETOOTH_CONNECT → BLUETOOTH legacy
```

Resolution happens inside the platform implementations, not here. The platform interface just declares the *intent*.

### 1.3 — Redesign `SimplePermissionsPlatform`

Replace the 10-method interface with 4 methods:

```dart
abstract class SimplePermissionsPlatform extends PlatformInterface {
  Future<PermissionGrant> check(Permission permission);
  Future<PermissionGrant> request(Permission permission);
  bool isSupported(Permission permission);
  Future<bool> openAppSettings();
}
```

Also expose batch convenience (can be implemented in terms of the single-permission methods by default):
```dart
Future<PermissionResult> checkAll(List<Permission> permissions);
Future<PermissionResult> requestAll(List<Permission> permissions);
```

### 1.4 — Update `PermissionGrant`

Add two new values:
```dart
enum PermissionGrant {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  notApplicable,     // concept doesn't exist on this platform
  notAvailable,      // NEW: exists on platform, but not this OS version
  provisional,       // NEW: iOS provisional notifications
}
```

### 1.5 — Replace `CapabilityResult` with `PermissionResult`

Same role but keyed on `Permission` instead of `PermissionCapability`:
```dart
class PermissionResult {
  final Map<Permission, PermissionGrant> permissions;
  // ...same helper getters (isFullyGranted, denied, permanentlyDenied, etc.)
}
```

### 1.6 — Move `Intention` to platform_interface as a composable class

```dart
class Intention {
  const Intention(this.name, this.permissions);
  final String name;
  final List<Permission> permissions;

  static const texting = Intention('texting', [ ... ]);
  static const calling = Intention('calling', [ ... ]);
  // etc.
}
```

### 1.7 — Deprecate old types

Keep `PermissionCapability`, `CapabilityResult`, and the old `SimplePermissionsPlatform` methods as `@Deprecated` with forwarding adapters for one version cycle. This lets the consuming app migrate incrementally rather than in a single atomic change.

### 1.8 — Update `_NoopSimplePermissionsPlatform`

Implement the new 4-method contract. Returns `granted` for all (same behavior).

### 1.9 — Tests

- All sealed class variants are `const`-constructible
- `PermissionResult` equality, hash, helpers
- `VersionedPermission` factory constructors exist for all known versioned pairs
- Noop platform returns `granted` for every `Permission` variant
- `Intention.texting.permissions` / `.calling.permissions` etc. return expected types
- Backward-compat: deprecated `checkCapability` still routes through new `check`

**Deliverable**: `simple_permissions_platform_interface` v2.0.0 with full sealed hierarchy, versioned permissions, slim platform contract, and deprecated shims.

---

## Phase 2: Android Implementation — Handler Registry

**Goal**: Replace the giant switch-case mapping in `SimplePermissionsAndroid` with a handler registry. Fix version-awareness. Fix the rationale inversion bug.

**Package**: `simple_permissions_android`

### 2.1 — Define handler abstractions

File: `lib/src/handlers/permission_handler.dart`

```dart
abstract class PermissionHandler {
  Future<PermissionGrant> check();
  Future<PermissionGrant> request();
  bool isSupported();  // SDK version check
}
```

Concrete subclasses:
| File | Class | Covers |
|------|-------|--------|
| `runtime_permission_handler.dart` | `RuntimePermissionHandler` | Standard `ActivityCompat.requestPermissions` flow. Takes permission string + optional `minSdk`/`maxSdk`. |
| `role_handler.dart` | `RoleHandler` | `RoleManager.requestRole()` flow. Takes role string. |
| `system_setting_handler.dart` | `SystemSettingHandler` | Things that open system settings intents (battery optimization, exact alarms). |

### 2.2 — Build the registry

File: `lib/src/android_permission_registry.dart`

Map from `Permission` runtime type → `PermissionHandler`:

```dart
final registry = <Type, PermissionHandler Function(HostApi, Context)>{
ReadMediaImages: (api, ctx) =>
  RuntimePermissionHandler(api, 'READ_MEDIA_IMAGES', minSdk: 33),
ReadExternalStorage: (api, ctx) =>
  RuntimePermissionHandler(api, 'READ_EXTERNAL_STORAGE', maxSdk: 32),
  DefaultSmsApp: (api, ctx) => RoleHandler(api, 'android.app.role.SMS'),
  BatteryOptimizationExemption: (api, ctx) => SystemSettingHandler(api),
  // ...every Permission type gets a handler
};
```

### 2.3 — Rewrite `SimplePermissionsAndroid` to use registry

The new `check(Permission p)` implementation:
1. Look up handler in registry by `p.runtimeType`
2. If not found → `PermissionGrant.notApplicable`
3. If found but `!handler.isSupported()` → `PermissionGrant.notAvailable`
4. Otherwise → `handler.check()`

### 2.4 — `VersionedPermission` resolution

When the platform receives a `VersionedPermission`, it calls `resolve(sdkVersion)` to get the concrete `Permission`, then looks that up in the registry. This is where the version auto-resolution happens.

### 2.5 — Fix the `shouldShowRequestPermissionRationale` bug

In `RuntimePermissionHandler.request()`:
- After denial, call `shouldShowRequestPermissionRationale`
- `true` → `PermissionGrant.denied` (user denied, can ask again)
- `false` AND was previously `notDetermined` → `PermissionGrant.denied` (first denial)
- `false` AND was previously `denied` → `PermissionGrant.permanentlyDenied` (checked "don't ask again")

Track the "was previously denied" state using the Pigeon `checkPermissions` call *before* requesting.

### 2.6 — Keep Pigeon bridge as-is

The Pigeon-generated code (`PermissionsHostApi`) and native Kotlin (PermissionsHostApiImpl.kt, SimplePermissionsAndroidPlugin.kt) remain the **transport layer**. They don't need to change — the low-level `checkPermissions(List<String>)`, `requestPermissions(List<String>)`, `isRoleHeld(String)`, `requestRole(String)` are still the right native primitives. The handlers wrap them.

### 2.7 — Backward-compat shims

Implement the deprecated `checkCapability(PermissionCapability)` by mapping old enum values to new `Permission` sealed class instances internally.

### 2.8 — Tests

- Each handler type unit tested with mock HostApi
- Registry coverage: every `Permission` variant has a registered handler
- Rationale bug fix: verify correct `denied` vs `permanentlyDenied` classification
- Backward-compat: old `PermissionCapability.canReadContacts` → new `ReadContacts()` equivalence

**Deliverable**: `simple_permissions_android` v2.0.0 with handler registry, version-aware resolution, rationale bug fix.

---

## Phase 3: iOS Completion

**Goal**: Expand iOS from 4 permission domains to 12+, switch from raw MethodChannel to Pigeon, implement `isSupported()`.

**Package**: `simple_permissions_ios`

### 3.1 — Create Pigeon definition

File: pigeon.dart

```dart
@HostApi()
abstract class PermissionsIosHostApi {
  @asyncCallback String checkPermission(String identifier);
  @asyncCallback String requestPermission(String identifier);
  bool isSupported(String identifier);
  bool openAppSettings();
}
```

Single `identifier`-based API — the Swift side has a registry of handlers, just like Android.

### 3.2 — Swift handler registry

Rewrite SimplePermissionsIosPlugin.swift to use a handler map:

```swift
private let handlers: [String: PermissionHandler] = [
  "read_contacts": ContactsHandler(.contacts),
  "write_contacts": ContactsHandler(.contacts),
  "camera_access": CameraHandler(),
  "record_audio": MicrophoneHandler(),
  "post_notifications": NotificationHandler(),
  "read_media_images": PhotoLibraryHandler(.readWrite),
  "read_media_video": PhotoLibraryHandler(.readWrite),
  "fine_location": LocationHandler(.whenInUse),
  "background_location": LocationHandler(.always),
  "read_calendar": CalendarHandler(.event),
  "write_calendar": CalendarHandler(.event),
  "app_tracking_transparency": TrackingHandler(),
  "body_sensors": MotionHandler(),
  // etc.
]
```

### 3.3 — Implement missing iOS permission handlers

| Domain | iOS Framework | Status |
|--------|--------------|--------|
| Contacts | `Contacts.framework` | Already done, keep |
| Notifications | `UserNotifications` | Already done, keep |
| Photos | `Photos.framework` | Already done, keep |
| Microphone | `AVFoundation` | Already done, keep |
| Camera | `AVFoundation` | **New** — `AVCaptureDevice.authorizationStatus(for: .video)` |
| Location | `CoreLocation` | **New** — `CLLocationManager.authorizationStatus` |
| Calendar | `EventKit` | **New** — `EKEventStore.authorizationStatus(for: .event)` |
| Reminders | `EventKit` | **New** — `EKEventStore.authorizationStatus(for: .reminder)` |
| Health | `HealthKit` | **New** — `HKHealthStore.authorizationStatus` |
| Motion | `CoreMotion` | **New** — `CMMotionActivityManager.authorizationStatus()` |
| Speech | `Speech` | **New** — `SFSpeechRecognizer.authorizationStatus()` |
| Tracking | `AppTrackingTransparency` | **New** — `ATTrackingManager.trackingAuthorizationStatus` |

### 3.4 — `isSupported()` per iOS version

Some permissions are iOS 14+ (ATT), iOS 17+ (certain Health changes). Handlers return `false` from `isSupported()` on older versions.

### 3.5 — iOS permissions that have no Android analog

`AppTrackingTransparency` → Android returns `notApplicable`. This is fine — the sealed class exists in the interface, each platform decides relevance.

### 3.6 — Dart-side `SimplePermissionsIos` rewrite

Mirror the Android approach: look up Permission identifier → call Pigeon → parse result.

### 3.7 — Tests

- Mock Pigeon HostApi for every handler
- `isSupported` returns false for unavailable iOS versions
- All iOS-native permissions map correctly to `PermissionGrant` values
- `restricted` and `limited` states tested (iOS-specific states)

**Deliverable**: `simple_permissions_ios` v2.0.0 with complete iOS coverage via Pigeon.

---

## Phase 4: App-Facing Package Update

**Goal**: Update the public `SimplePermissions` API, replace `Intention` enum with composable class, add debug-mode validation.

**Package**: `simple_permissions_native` (root)

### 4.1 — New public API

```dart
class SimplePermissions {
  // New API
  Future<PermissionGrant> check(Permission permission);
  Future<PermissionGrant> request(Permission permission);
  Future<PermissionResult> checkAll(List<Permission> permissions);
  Future<PermissionResult> requestAll(List<Permission> permissions);
  bool isSupported(Permission permission);
  Future<bool> openAppSettings();

  // Intention convenience
  Future<bool> checkIntention(Intention intention);
  Future<bool> requestIntention(Intention intention);
  Future<PermissionResult> checkIntentionDetailed(Intention intention);
  Future<PermissionResult> requestIntentionDetailed(Intention intention);

  // Deprecated shims (removed in v3)
  @Deprecated('Use check() with Permission sealed classes')
  Future<PermissionGrant> checkCapability(PermissionCapability capability);
  // etc.
}
```

### 4.2 — Debug-mode coverage validation

In `initialize()`, run `VersionedPermission` validation in `assert()` block:
- Warn if a versioned permission is used without its fallback pair
- Warn if platform-specific permissions are requested without guards

### 4.3 — Export all Permission types

```dart
export 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart'
    show Permission, CameraAccess, ReadContacts, WriteContacts, // ...all types
         PermissionGrant, PermissionResult, Intention,
         VersionedPermission;
```

### 4.4 — Update exports to re-export `@Deprecated` old types alongside new

### 4.5 — Tests

- All new API methods work through noop platform
- `Intention.texting` / `.calling` etc. return correct `Permission` instances
- Debug validation fires for incomplete versioned permission sets
- Deprecated methods still work and produce correct results

**Deliverable**: `simple_permissions_native` v2.0.0.

---

## Phase 5: macOS Platform (stretch)

**Goal**: Create `simple_permissions_macos` for desktop-relevant permissions.

**Package**: `simple_permissions_macos` (new)

### 5.1 — Scaffold package

Standard federated plugin structure: pubspec.yaml, Classes, Pigeon definition.

### 5.2 — macOS permission domains

| Domain | macOS Framework | Notes |
|--------|----------------|-------|
| Contacts | `Contacts.framework` | Same as iOS |
| Calendar | `EventKit` | Same as iOS |
| Camera | `AVFoundation` | System Preferences prompt |
| Microphone | `AVFoundation` | System Preferences prompt |
| Photos | `Photos.framework` | Limited Library, Full Library |
| Location | `CoreLocation` | macOS 10.15+ |
| Screen Recording | `CGPreflightScreenCaptureAccess()` | macOS 15+ has newer API |
| Accessibility | `AXIsProcessTrusted()` | No direct request — opens System Preferences |

### 5.3 — Register in root pubspec.yaml

Add `macos: default_package: simple_permissions_macos`.

### 5.4 — Tests

- Mock-based Pigeon tests for each domain
- `isSupported` correctly reports macOS version availability

**Deliverable**: `simple_permissions_macos` v1.0.0.

---

## Phase 6: Consuming App Migration

**Goal**: Migrate `simple-messages` from the v1 string-based API to v2 sealed-class API, absorb `AppPermissions` version logic into the plugin, remove `permission_handler` dead dependency.

**Package**: `simple-messages` (consuming app)

### 6.1 — Update pubspec.yaml

- Point `simple_permissions` path dep to the v2 version
- Remove `permission_handler: ^11.4.0` (dead dependency, zero imports)

### 6.2 — Migrate `AppPermissions`

The current `AppPermissions` class in the consuming app does its own version-aware permission string mapping. With v2, this becomes:

```dart
// Before (v1)
List<String> _mediaImageVideoPermissions() => _isAndroid13OrAbove
    ? const ['android.permission.READ_MEDIA_IMAGES', 'android.permission.READ_MEDIA_VIDEO']
    : const ['android.permission.READ_EXTERNAL_STORAGE'];

// After (v2) — version resolution is the plugin's job
static const photosAndVideos = Intention('photos_and_videos', [
  VersionedPermission.images(),
  VersionedPermission.video(),
]);
```

`AppPermissions.ensure()` becomes a thin wrapper over `SimplePermissions.instance.requestIntention()`:

```dart
Future<PermissionResult> ensure(AppPermission permission) {
  return SimplePermissions.instance.requestIntentionDetailed(
    permission.toIntention(),
  );
}
```

### 6.3 — Migrate `PermissionStateNotifier`

Replace `checkPermissions(List<String>)` calls with `checkAll(List<Permission>)`:
```dart
// Before
final map = await _checkPermissions(perms);
state = state.copyWith(permissions: Map<String, bool>.from(map));

// After
final result = await SimplePermissions.instance.checkAll(perms);
state = state.copyWith(permissionResult: result);
```

Replace `isRoleHeld('android.app.role.SMS')` with `check(DefaultSmsApp())`.

### 6.4 — Update `PermissionState` model

Replace `Map<String, bool> permissions` with `PermissionResult` or a map keyed on `Permission` types instead of Android string constants.

### 6.5 — Remove dead files

- Delete or un-comment android_permissions.dart (100% commented out)
- Remove permission_banners.dart (deprecated `SizedBox.shrink()` placeholder)

### 6.6 — Test the consuming app

- `flutter analyze` passes
- `flutter test` passes
- Manual testing on API 30 and API 34 devices confirms versioned resolution works
- Debug console shows no coverage validation warnings

**Deliverable**: `simple-messages` fully migrated, no legacy permission APIs, no dead dependencies.

---

## Phase 7: Cleanup & v3 Prep

### 7.1 — Remove deprecated shims from platform_interface, android, ios, app-facing
### 7.2 — Update all copilot-instructions.md files
### 7.3 — Update PROJECT_WHITEPAPER.md
### 7.4 — Final test pass across all packages

---

## Execution Order & Dependencies

```
Phase 1 (platform_interface)
    ├── Phase 2 (android) ──────────────┐
    ├── Phase 3 (ios) ──────────────────┤
    └── Phase 4 (app-facing) ───────────┤
         └── Phase 5 (macos) [optional] │
                                        ▼
                                  Phase 6 (consuming app migration)
                                        │
                                        ▼
                                  Phase 7 (cleanup)
```

Phases 2, 3, and 4 can proceed **in parallel** once Phase 1 is complete. Phase 6 requires 2 + 4 (Android + app-facing) at minimum. Phase 5 is optional / stretch and doesn't block anything.

## Estimated Scope

| Phase | Files Changed/Created | Complexity |
|-------|----------------------|-----------|
| 1 — Platform Interface | ~20 new, ~5 modified | High (foundational design decisions) |
| 2 — Android | ~10 new, ~3 modified | Medium-High (handler registry, bug fix) |
| 3 — iOS | ~15 new, ~3 modified | Medium (many handlers but pattern is repetitive) |
| 4 — App-Facing | ~3 modified | Low-Medium |
| 5 — macOS | ~12 new | Medium |
| 6 — Consuming App | ~5 modified, ~2 deleted | Medium (careful migration) |
| 7 — Cleanup | ~10 modified | Low |
