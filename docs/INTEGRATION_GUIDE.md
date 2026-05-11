# Integration Guide

This guide is for **client-app developers** building a Flutter app that uses `simple_permissions_native` and — optionally — writes native Kotlin or Swift code alongside it (app extensions, native UI components, custom `AppDelegate` work, native modules you own).

The two things this guide covers:

1. **Dart gate helpers** on `SimplePermissionsNative` — the sanctioned "check → request → act" pattern for normal Flutter code.
2. **Native `PermissionGuards`** on Android (Kotlin) and iOS / macOS (Swift) — the helpers for when your app has its own native code that touches permission-gated APIs.

If you're only using simple-permissions from Dart and don't write your own native code, you only need section 1. If your app has a hand-rolled Kotlin `MethodChannel` or a Swift extension that touches `CNContactStore`, read both.

> **A note on responsibility**: sibling plugins (plugins that depend on permissions to do their work — e.g. a sibling "read contacts" plugin) **do not** embed `simple_permissions_native` or wire `PermissionGuards` into their own native code. Those plugins just call their framework APIs; **your app** is responsible for ensuring permissions are granted — typically via `SimplePermissionsNative.instance.ensureGranted(...)` — before invoking the sibling plugin. This keeps the permission model centralized in one place (your app) rather than duplicated across every plugin you use.

---

## 1. Dart gate helpers

The facade ships six gate methods on `SimplePermissionsNative.instance`. Two shapes, three arities.

### Imperative: `ensureGranted` / `ensureGrantedAll` / `ensureIntention`

Use these when you need to know *why* a permission wasn't granted (to route to settings, show rationale, branch on denial mode).

```dart
final grant = await SimplePermissionsNative.instance
    .ensureGranted(const ReadContacts());

switch (grant) {
  case PermissionGrant.granted:
  case PermissionGrant.limited:
  case PermissionGrant.provisional:
    await _syncContacts();
  case PermissionGrant.permanentlyDenied:
    await _showOpenSettingsPrompt();
  case PermissionGrant.denied:
  case PermissionGrant.restricted:
    _showRationale();
  case PermissionGrant.notApplicable:
  case PermissionGrant.notAvailable:
    _disableFeature(); // not supported on this OS
}
```

`ensureGranted` short-circuits on already-satisfied grants *and* on terminal grants (permanentlyDenied, restricted, notApplicable, notAvailable) — requesting those is a no-op. The batch form (`ensureGrantedAll`) forwards only the prompt-worthy permissions to a single `requestAll` round-trip.

### Run-with: `guard` / `guardAll` / `guardIntention`

Use these when you just want the action to run on success:

```dart
final contacts = await SimplePermissionsNative.instance.guard(
  const ReadContacts(),
  () => _fetchContacts(),
);

if (contacts == null) {
  // Permission wasn't granted; surface whatever UX fits.
  return;
}

_render(contacts);
```

`guard` returns the action's value on success, `null` on any non-satisfied grant. If you need to distinguish denial modes, use `ensureGranted` instead.

---

## 2. Native PermissionGuards

If your app has Kotlin or Swift code that touches permission-gated framework APIs directly, `PermissionGuards` is the sanctioned way to check / require / request authorization from native code without reaching for Apple's or Google's raw APIs.

### Android (Kotlin)

#### Android lint wants two signals at every permission-gated method

Android's `MissingPermission` lint looks for `@RequiresPermission` on the caller. It doesn't recognize custom helper functions, so `PermissionGuards.isPermissionGranted(...)` alone won't silence the warning. Combine both:

1. **`@RequiresPermission(anyOf = [...])`** on your method — satisfies lint; propagates the requirement to callers of your own code.
2. **`PermissionGuards.requireAnyPermissionGranted(context, [...])`** inside the method — throws `PermissionDeniedException` (a `SecurityException` subclass) if the caller reached this method without the permission. Clear domain error instead of the framework's opaque `SecurityException`.

```kotlin
import android.Manifest
import androidx.annotation.RequiresPermission
import io.simplezen.simple_permissions_android.PermissionGuards

@RequiresPermission(anyOf = [
    Manifest.permission.CALL_PHONE,
    Manifest.permission.MANAGE_OWN_CALLS,
])
fun placeCall(uri: Uri) {
    PermissionGuards.requireAnyPermissionGranted(context, listOf(
        Manifest.permission.CALL_PHONE,
        Manifest.permission.MANAGE_OWN_CALLS,
    ))
    telecomManager.placeCall(uri, Bundle())
}
```

Pick the helper that matches the framework contract:

| Framework contract                         | Helper                              |
| ------------------------------------------ | ----------------------------------- |
| Needs one specific permission              | `requirePermissionGranted`          |
| Accepts any of several (e.g. `placeCall`)  | `requireAnyPermissionGranted`       |
| Needs all of several (e.g. SMS read+write) | `requireAllPermissionsGranted`      |
| Needs an app role (e.g. default SMS/Dialer) | `requireRoleHeld`                   |

All four throw `PermissionDeniedException` on failure; the exception's `.deniedPermissions` lists exactly what's missing (not the full required set) so callers can surface precise error UI.

#### Adopting it in your project

Two lines. In your app's `android/build.gradle[.kts]`:

```kotlin
dependencies {
    implementation(project(":simple_permissions_android"))
}
```

Flutter's plugin-loader walks the pubspec graph at app-build time and synthesizes Gradle project entries for every federated plugin's Android module into the final app's build, so `:simple_permissions_android` resolves alongside your app code. Now `import io.simplezen.simple_permissions_android.PermissionGuards` works in your Kotlin.

#### Manifest declarations — `<uses-permission>` vs `<service android:permission="…">`

Not all Android permissions are requestable. They split across two manifest shapes, and lint will complain if you get them confused.

- **Runtime permissions** (dangerous + normal, requestable): declared via `<uses-permission>`. These are what `simple_permissions_native` requests through its Dart API. Example: `android.permission.CALL_PHONE`, `android.permission.READ_CONTACTS`.
- **System-only `BIND_*` permissions**: declared as `android:permission="…"` on the `<service>` or `<receiver>` the framework binds to. Your app never holds these; the *system* does. Putting them in `<uses-permission>` triggers a lint warning and does nothing useful.

```xml
<!-- WRONG — system-only permission in uses-permission. -->
<uses-permission android:name="android.permission.BIND_INCALL_SERVICE" />

<!-- RIGHT — on the service declaration. Only a process holding
     BIND_INCALL_SERVICE (the system) can bind to this service. -->
<service
    android:name=".MyInCallService"
    android:permission="android.permission.BIND_INCALL_SERVICE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.telecom.InCallService" />
    </intent-filter>
</service>
```

Common `BIND_*` permissions and where they belong:

| Permission                             | Goes on `<…>`                                     |
| -------------------------------------- | ------------------------------------------------- |
| `BIND_INCALL_SERVICE`                  | `<service>` extending `InCallService`             |
| `BIND_SCREENING_SERVICE`               | `<service>` extending `CallScreeningService`      |
| `BIND_VISUAL_VOICEMAIL_SERVICE`        | `<service>` extending `VisualVoicemailService`    |
| `BIND_NOTIFICATION_LISTENER_SERVICE`   | `<service>` extending `NotificationListenerService` |
| `BIND_ACCESSIBILITY_SERVICE`           | `<service>` extending `AccessibilityService`      |
| `BIND_DEVICE_ADMIN`                    | `<receiver>` extending `DeviceAdminReceiver`      |
| `BIND_VPN_SERVICE`                     | `<service>` extending `VpnService`                |

None of these are runtime-requestable.

---

### iOS and macOS (Swift)

The Swift `PermissionGuards` ships three API shapes. Pick the shape that matches your call site's needs.

#### 2.1 Read status — `authorizationStatus(for:)` and `isAuthorized(for:)`

`authorizationStatus(for:)` returns the full 8-case `PermissionGrant` mirror of the Dart-side enum. Use when you need to distinguish denial modes.

```swift
import simple_permissions_ios   // or simple_permissions_macos on macOS

switch PermissionGuards.authorizationStatus(for: .contacts) {
case .granted, .limited:
    proceed()
case .permanentlyDenied:
    showOpenSettingsButton()
case .denied:
    showRationaleThenPrompt()
case .restricted:
    showParentalControlsMessage()
case .notApplicable, .notAvailable:
    disableFeature()
case .provisional:
    proceed()  // notifications-only; never returned by non-notifications kinds
}
```

`PermissionGrant` comes with the same `isSatisfied`, `isDenied`, `isUnsupported`, `isTerminal` predicates as the Dart side. Use `isAuthorized(for:)` when you just want a Bool:

```swift
if PermissionGuards.isAuthorized(for: .camera) {
    startCamera()
}
```

#### 2.2 Assert — `requireAuthorized(for:)` and variants

Throws `PermissionDeniedError` if the required authorization isn't held. Use at the top of a method about to invoke a framework API requiring that authorization:

```swift
func startCall() throws {
    // Accepts any of the listed kinds (CallKit accepts mic or manage-own-calls analog).
    try PermissionGuards.requireAnyAuthorized(for: [.microphone])
    // CallKit / AVCaptureSession setup…
}

func syncContactsAndCalendar() throws {
    try PermissionGuards.requireAllAuthorized(for: [.contacts, .calendar])
    // Fetch using CNContactStore / EKEventStore…
}
```

Pick by framework contract:

| Framework contract                         | Helper                                |
| ------------------------------------------ | ------------------------------------- |
| Needs one specific authorization           | `requireAuthorized(for:)`             |
| Accepts any of several equivalents         | `requireAnyAuthorized(for:)`          |
| Needs all of several                       | `requireAllAuthorized(for:)`          |
| Notifications (async-only framework API)   | `requireNotificationsAuthorized()`    |

`PermissionDeniedError.deniedPermissions: [String]` names what was missing (only the missing subset in `requireAll*`, not the full input).

#### 2.3 Request — `requestAuthorization(for:)` async

Triggers the system prompt (on first use) and returns the post-prompt grant. Short-circuits without prompting when already decided:

```swift
let grant = await PermissionGuards.requestAuthorization(for: .camera)
if grant.isSatisfied {
    startCamera()
} else {
    // grant == .permanentlyDenied → Settings link
    // grant == .restricted → parental controls message
    // grant == .denied → user just said no but might reconsider
}
```

Or use the throwing variant to fail loudly instead of branching:

```swift
try await PermissionGuards.requireAuthorizationGranted(for: .camera)
startCamera()
```

Notifications have their own async helpers because `UNUserNotificationCenter` is async-only:

```swift
let grant = await PermissionGuards.requestNotificationsAuthorization()
try await PermissionGuards.requireNotificationsAuthorizationGranted()
```

#### 2.4 Covered kinds

**iOS** (`ApplePermissionKind`): `.contacts`, `.camera`, `.microphone`, `.calendar`, `.reminders`, `.photoLibrary`, `.photoLibraryAddOnly`, `.location`, `.speech`, `.tracking`, `.motion`, `.bluetooth`, `.health(HKObjectType)`.

**macOS** (`MacOSPermissionKind`): `.contacts`, `.camera`, `.microphone`, `.calendar`, `.reminders`, `.photoLibrary`, `.photoLibraryAddOnly`, `.location`.

#### 2.5 HealthKit — `.health(HKObjectType)` (iOS only)

HealthKit authorization is keyed per-object-type. Pass the specific `HKObjectType` you need:

```swift
import HealthKit

guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
try await PermissionGuards.requireAuthorizationGranted(for: .health(stepType))
// HKHealthStore read/write for stepType…
```

**Apple privacy caveat**: `HKHealthStore.authorizationStatus(for:)` only reflects **write** authorization. Read authorization is opaque by design — Apple prevents apps from inferring "user has no data" from "app has no read access." So `isAuthorized(for: .health(type))` returning true means "can write," not "can read." For read-gated flows, attempt the `HKSampleQuery` and handle empty/error results rather than pre-check.

The request path asks for both read and write where the type supports it, so the user sees a single consolidated prompt.

#### 2.6 Adopting it in your project

One line in your app's `ios/Podfile` target:

```ruby
# simple_permissions_ios is already pulled in transitively by
# simple_permissions_native; nothing extra to declare.
```

In your Swift code:

```swift
import simple_permissions_ios  // or simple_permissions_macos
```

The `DEFINES_MODULE => YES` flag on the plugin's podspec is already set, so the module resolves without extra wiring.

#### 2.7 Info.plist — usage-description keys

Every Apple framework with a permission prompt requires a matching `NS*UsageDescription` string in your app's `Info.plist`, or the app **crashes** the moment the framework is invoked. simple-permissions doesn't inject these — you own the strings, they're user-facing, and Apple requires you to explain why you're asking.

| Framework            | Key                                          |
| -------------------- | -------------------------------------------- |
| Contacts             | `NSContactsUsageDescription`                 |
| Camera               | `NSCameraUsageDescription`                   |
| Microphone           | `NSMicrophoneUsageDescription`               |
| Calendar (iOS 17+)   | `NSCalendarsFullAccessUsageDescription`      |
| Reminders (iOS 17+)  | `NSRemindersFullAccessUsageDescription`      |
| Photo Library (R/W)  | `NSPhotoLibraryUsageDescription`             |
| Photo Library (add)  | `NSPhotoLibraryAddUsageDescription`          |
| Location (WhenInUse) | `NSLocationWhenInUseUsageDescription`        |
| Location (Always)    | `NSLocationAlwaysAndWhenInUseUsageDescription` |
| Bluetooth            | `NSBluetoothAlwaysUsageDescription`          |
| Speech Recognition   | `NSSpeechRecognitionUsageDescription`        |
| Tracking             | `NSUserTrackingUsageDescription`             |
| Motion               | `NSMotionUsageDescription`                   |
| HealthKit            | `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` |

---

## Checklist for adopting simple-permissions in your app

- [ ] Call `await SimplePermissionsNative.initialize()` once in `main()` alongside `WidgetsFlutterBinding.ensureInitialized()`.
- [ ] For every permission-gated flow: use `ensureGranted` / `guard` rather than hand-rolling check → request → act.
- [ ] If your app has its own native Kotlin code: add `@RequiresPermission` + `PermissionGuards.requireX` on any method calling a permission-gated framework API.
- [ ] If your app has its own native Swift code: call `try PermissionGuards.requireAuthorized(for: …)` (or its async request counterpart) at the top of any permission-gated method.
- [ ] Android: no `BIND_*` permission in `<uses-permission>`. Every system-bound service has `android:permission="..."` on the `<service>` itself.
- [ ] iOS / macOS: every `NS*UsageDescription` key for every permission the app requests is in `Info.plist`.

---

## See also

- [`lib/simple_permissions_native.dart`](../lib/simple_permissions_native.dart) — Dart facade, including the gate helpers.
- [`PermissionGuards.kt`](../packages/simple_permissions_android/android/src/main/kotlin/io/simplezen/simple_permissions_android/PermissionGuards.kt) — Android native assertions.
- [`PermissionGuards.swift` (iOS)](../packages/simple_permissions_ios/ios/Classes/PermissionGuards.swift) — iOS native check / require / request.
- [`PermissionGuards.swift` (macOS)](../packages/simple_permissions_macos/macos/Classes/PermissionGuards.swift) — macOS equivalent.
- [`example/lib/main.dart`](../example/lib/main.dart) — `guard`-based demo card for the Dart side.
