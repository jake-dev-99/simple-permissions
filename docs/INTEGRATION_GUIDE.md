# Integration Guide — Sibling Plugins & Client Apps

This guide is for:

- **Client-app developers** who want a sanctioned "check → request → act" pattern without reinventing it every time.
- **Sibling-plugin authors** (plugins that depend on `simple_permissions_native` because their own operations are permission-gated — e.g. `simple_telephony`, `simple_sms`, `simple_query`) who need their native code to be lint-clean *and* keep separation of concerns.

If you only want to check or request a permission, you don't need this guide — `SimplePermissionsNative.instance.check(...)` / `.request(...)` are all you need. Read on when you're combining those calls with an action, or building a plugin on top of simple-permissions.

---

## The three-layer responsibility model

The line between "library helps" and "client policy" matters. A sibling plugin that silently requests permissions surprises users; a client app that reimplements the request-gate from scratch drifts into subtly-different bugs. Pin each responsibility to exactly one layer:

| Layer                       | Owns                                                                                                          | Does NOT                                              |
| --------------------------- | ------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| **Client app (Dart)**       | *When* to prompt. Rationale UI. Routing to settings on permanent denial. Calls `ensureGranted` / `guard`.     | Reach into native code. Hand-roll check/request logic. |
| **Sibling plugin (Dart)**   | Declares the permissions its operations need. Returns domain results.                                         | Prompt on the client's behalf. Hold permission policy. |
| **Sibling plugin (native)** | `@RequiresPermission` annotations for lint. `PermissionGuards.require*` for runtime defense. Framework calls. | Request permissions. Show UI.                         |

The native side *asserts*, never *requests*. The Dart side of the sibling plugin *declares*, never *decides*. The client app *decides*.

---

## Client-app patterns — Dart gate helpers

The facade ships six gate methods. Two shapes, three arities.

### Imperative: `ensureGranted` / `ensureGrantedAll` / `ensureIntention`

Use these when you need to know *why* a permission wasn't granted (to route to settings, show rationale, etc.).

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

`ensureGranted` short-circuits on already-satisfied grants *and* on terminal grants (permanentlyDenied, restricted, notApplicable, notAvailable) — requesting those is a no-op on every platform. The batch form forwards only the prompt-worthy permissions to a single `requestAll` round-trip.

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

## Sibling-plugin patterns — Android native

### Android lint wants two signals at every permission-gated method

`MissingPermission` lint looks for `@RequiresPermission` on the caller. It doesn't recognize custom helper functions, so a `PermissionGuards.isPermissionGranted(...)` call alone won't silence the warning. Instead, combine:

1. **`@RequiresPermission(anyOf = [...])`** on the method — satisfies lint; propagates the requirement to callers of *your* plugin.
2. **`PermissionGuards.requireAnyPermissionGranted(context, [...])`** inside the method — throws `PermissionDeniedException` (a `SecurityException` subclass) if the caller skipped the Dart-side `ensureGranted` and reached the native method without the permission. Clear domain error instead of the framework's opaque `SecurityException`.

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

### Manifest declarations — `<uses-permission>` vs `<service android:permission="…">`

Not all permissions are requestable. Android splits them across two manifest shapes, and lint will complain if you get them confused.

- **Runtime permissions** (dangerous + normal, requestable): declared via `<uses-permission>`. These are what `simple_permissions_native` requests through its Dart API. Example: `android.permission.CALL_PHONE`, `android.permission.READ_CONTACTS`.
- **System-only `BIND_*` permissions**: declared as `android:permission="…"` on the `<service>` or `<receiver>` that the framework binds to. The app never holds these; the *system* does. Putting them in `<uses-permission>` triggers a lint warning and does nothing useful.

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
| `BIND_CARRIER_MESSAGING_SERVICE`       | `<service>` for carrier SMS plugin                |
| `BIND_NOTIFICATION_LISTENER_SERVICE`   | `<service>` extending `NotificationListenerService` |
| `BIND_ACCESSIBILITY_SERVICE`           | `<service>` extending `AccessibilityService`      |
| `BIND_DEVICE_ADMIN`                    | `<receiver>` extending `DeviceAdminReceiver`      |
| `BIND_VPN_SERVICE`                     | `<service>` extending `VpnService`                |

None of these are runtime-requestable, and none of them belong in simple-permissions' `Permission` sealed hierarchy — that hierarchy intentionally only enumerates things a client app *can* request.

---

## Sibling-plugin patterns — iOS / macOS

Apple has no lint-equivalent for missing authorization — the separation-of-concerns model still applies, but there's only one signal (the runtime assertion). Since 1.7.0, the iOS and macOS modules ship a `PermissionGuards` Swift namespace that mirrors the Kotlin one.

### Single signal: `PermissionGuards.require*`

```swift
import simple_permissions_ios   // or simple_permissions_macos on macOS

func startCall(to uri: URL) throws {
    // Accepts any of the listed kinds, matching the equivalent
    // Kotlin `requireAnyPermissionGranted` shape used on Android.
    try PermissionGuards.requireAnyAuthorized(for: [.microphone])
    // framework call — CXCallController.requestTransaction, etc.
}

func syncContacts() throws {
    try PermissionGuards.requireAuthorized(for: .contacts)
    // CNContactStore fetch
}

func syncCalendar() throws {
    try PermissionGuards.requireAllAuthorized(for: [.calendar, .reminders])
    // EKEventStore fetch
}
```

On missing authorization each helper throws a library-specific `PermissionDeniedError` whose `.deniedPermissions: [String]` lists the missing kind names — so callers can surface precise error UI rather than whatever opaque status their framework call returned.

Pick the helper that matches the framework contract:

| Framework contract                         | Helper                          |
| ------------------------------------------ | ------------------------------- |
| Needs one specific authorization           | `requireAuthorized(for:)`       |
| Accepts any of several equivalents         | `requireAnyAuthorized(for:)`    |
| Needs all of several                       | `requireAllAuthorized(for:)`    |
| Notifications (async-only framework API)   | `requireNotificationsAuthorized()` |

### Covered kinds

**iOS** (`ApplePermissionKind`, 12 cases): `.contacts`, `.camera`, `.microphone`, `.calendar`, `.reminders`, `.photoLibrary`, `.photoLibraryAddOnly`, `.location`, `.speech`, `.tracking`, `.motion`, `.bluetooth`.

**macOS** (`MacOSPermissionKind`, 8 cases): `.contacts`, `.camera`, `.microphone`, `.calendar`, `.reminders`, `.photoLibrary`, `.photoLibraryAddOnly`, `.location`.

### Explicitly NOT covered

- **`.health`** — `HKHealthStore.authorizationStatus(for:)` is parameterized by `HKObjectType`, so a single case can't carry the type. Sibling plugins needing HealthKit gating call the framework directly with a domain wrapper. The helpers will grow a health case when a concrete `simple-health` plugin materializes.

### Info.plist — the Apple equivalent of `<uses-permission>`

Apple has no direct analog to Android's `<service android:permission="…">` split, but the parallel worth knowing: **usage-description strings belong in the client app's `Info.plist`, not in any sibling plugin**.

Every dangerous framework (`NSCameraUsageDescription`, `NSContactsUsageDescription`, `NSMicrophoneUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `NSRemindersFullAccessUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSBluetoothAlwaysUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSUserTrackingUsageDescription`, `NSMotionUsageDescription`) requires its usage-description key or the app crashes the moment the framework is invoked. A sibling plugin **should not** inject these keys — the app author decides what string the user sees. The plugin's README should list the keys the app needs; simple-permissions' README already does this in the "iOS setup" section.

### Adopting it in your plugin

One line in your podspec:

```ruby
s.dependency 'simple_permissions_ios'   # or _macos
```

The `DEFINES_MODULE => YES` flag on simple-permissions's podspec is already set, so `import simple_permissions_ios` in your Swift code resolves without further module-map wiring.

---

## Checklist for a new sibling plugin

Before shipping, verify:

- [ ] The plugin's Dart API **declares** its required permissions via the `simple_permissions_platform_interface` types — does not call `request(...)` itself.
- [ ] Every native Kotlin method that invokes a permission-gated framework API is annotated with `@RequiresPermission(...)`.
- [ ] That same method calls the appropriate `PermissionGuards.require*` as the *first* statement, before any framework call.
- [ ] `./gradlew :<plugin>:lintDebug` passes with zero `MissingPermission` errors.
- [ ] No `BIND_*` permission in `<uses-permission>`. Every system-bound service has `android:permission="..."` on the `<service>` itself.
- [ ] iOS/macOS handlers call `try PermissionGuards.requireAuthorized(for: …)` (or the `Any` / `All` / async-notifications variants) as the first statement of any permission-gated method.
- [ ] The client app's `Info.plist` documents every `NS*UsageDescription` key the plugin requires; the plugin itself does NOT inject them.
- [ ] The plugin's README links to this guide rather than re-explaining the pattern.

---

## See also

- [`lib/simple_permissions_native.dart`](../lib/simple_permissions_native.dart) — facade, including the gate helpers.
- [`PermissionGuards.kt`](../packages/simple_permissions_android/android/src/main/kotlin/io/simplezen/simple_permissions_android/PermissionGuards.kt) — Android native assertions.
- [`PermissionGuards.swift` (iOS)](../packages/simple_permissions_ios/ios/Classes/PermissionGuards.swift) — iOS native assertions.
- [`PermissionGuards.swift` (macOS)](../packages/simple_permissions_macos/macos/Classes/PermissionGuards.swift) — macOS native assertions.
- [`example/lib/main.dart`](../example/lib/main.dart) — `guard`-based demo card.
