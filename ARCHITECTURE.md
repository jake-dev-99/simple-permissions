# Architecture

This document explains **why** the code is structured the way it is. Read
the README first for usage — this is for people who need to modify or extend
the plugin.

## The big picture

```
┌─────────────────────────────────────────────────────┐
│  Your Flutter app                                   │
│  import 'package:simple_permissions_native/...'     │
│                                                     │
│  SimplePermissionsNative.instance.check(...)        │
└──────────────────┬──────────────────────────────────┘
                   │  calls
┌──────────────────▼──────────────────────────────────┐
│  SimplePermissionsPlatform  (abstract contract)     │
│  packages/simple_permissions_platform_interface/     │
│                                                     │
│  Defines: Permission types, PermissionGrant,        │
│           PermissionResult, Intention, etc.          │
└──┬──────────┬──────────┬──────────┬─────────────────┘
   │          │          │          │  implements
   ▼          ▼          ▼          ▼
 Android    iOS       macOS       Web
 (Kotlin)  (Swift)   (Swift)   (JS interop)
```

At runtime, Flutter's federated plugin system picks the right implementation
based on the platform. Your app code never imports a platform package directly.

## Why sealed classes for permissions?

Most permission plugins use enums or strings. We use Dart 3 sealed classes:

```dart
sealed class Permission { ... }
  sealed class CameraPermission extends Permission { ... }
    class CameraAccess extends CameraPermission { ... }
  sealed class LocationPermission extends Permission { ... }
    class FineLocation extends LocationPermission { ... }
    class CoarseLocation extends LocationPermission { ... }
    class BackgroundLocation extends LocationPermission { ... }
```

**Why this matters:**

1. **Exhaustive switch** — the compiler forces you to handle all cases
2. **No typos** — `CameraAccess()` vs `"camera_access"` catches mistakes at compile time
3. **Grouping** — `LocationPermission` groups all location variants for pattern matching
4. **Const-constructible** — `const CameraAccess()` works in annotations, const lists, etc.

Each permission has an `identifier` string (`'camera_access'`, `'fine_location'`)
that platform implementations use to look up native handlers.

## Why each platform is different

### Android: handler registry + typed handlers

Android has three fundamentally different permission mechanisms:

1. **Runtime permissions** — `ActivityCompat.requestPermissions()` with a dialog
2. **App roles** — `RoleManager.requestRole()` to become default SMS/dialer app
3. **System settings** — `startActivityForResult()` with a Settings intent

These can't be unified into one native call, so the Android implementation uses
a **handler registry** that maps `Permission` runtime types to handler objects:

```
Permission type → PermissionHandler
  CameraAccess  → RuntimePermissionHandler("android.permission.CAMERA")
  DefaultSmsApp → RoleHandler("android.app.role.SMS")
  BatteryOptimizationExemption → SystemSettingHandler(batteryOptimization)
```

This pattern keeps each handler simple and independently testable.

**SDK version resolution**: Android's permission landscape changes across API
levels (storage split at API 33, Bluetooth split at API 31). `VersionedPermission`
handles this — it carries a list of variants with API-level bounds, and the
Android implementation picks the right one for the running device.

### iOS / macOS: identifier dispatch via Pigeon

Apple platforms use a simpler pattern:

1. Dart side maps `Permission` types to identifier strings
2. Identifier is sent to Swift via Pigeon (Flutter's code-gen bridge)
3. Swift looks up the identifier in a handler registry
4. Handler calls the appropriate Apple framework API

iOS and macOS are separate packages (Flutter requires this) but share a
common helper layer in `darwin_permission_utils.dart` in the platform interface.
This helper resolves `VersionedPermission`s, parses wire strings, and runs the
Pigeon call — so the iOS/macOS Dart classes are thin wrappers.

**Why separate from Android's approach?** Apple doesn't have Android's
three-mechanism split. Every Apple permission is "call a framework API, get
a status back." The identifier-dispatch pattern is simpler and sufficient.

### Web: browser Permissions API + conditional imports

The web has its own permission model:

- **Check**: `navigator.permissions.query({name: 'camera'})` → `'granted'` | `'denied'` | `'prompt'`
- **Request**: Each permission has its own API (`getUserMedia`, `Notification.requestPermission`, etc.)

Only 4 permission types have web equivalents: camera, microphone, geolocation,
notifications. Everything else returns `notApplicable`.

**Why conditional imports?** The browser API (`package:web`, `dart:js_interop`)
isn't available on the Dart VM where unit tests run. We solve this with:

```dart
// In simple_permissions_web.dart:
import 'src/api_factory_stub.dart'                    // ← VM (tests)
    if (dart.library.js_interop) 'src/api_factory_web.dart'; // ← browser
```

Both files export a `createBrowserApi()` function. The stub throws
`UnsupportedError` (never called in tests because the mock is injected).
The web version returns a real `BrowserPermissionsApi`.

## The testability pattern

Every platform follows the same strategy for testability:

1. Define an **abstract interface** for native calls (`PermissionsApi`, `PermissionsIosApi`, `WebPermissionsApi`)
2. Provide a **production adapter** that delegates to the real native bridge (Pigeon-generated class, browser JS APIs)
3. Accept the interface via **constructor injection** — tests pass a mock, production uses the default

```dart
// Production: uses real Pigeon bridge
SimplePermissionsAndroid()

// Test: uses fake
SimplePermissionsAndroid(api: MockPermissionsApi())
```

This means unit tests never touch platform channels or browser APIs — they
test pure Dart logic against a controllable fake.

## Android's rationale classification

When a user denies an Android permission, we need to distinguish:

- **Denied** (can ask again) vs. **Permanently denied** ("Don't ask again" checked)

Android doesn't have a direct API for this. Instead, we use
`shouldShowRequestPermissionRationale()` which returns:

- `false` → first time (never asked) OR permanently denied
- `true` → denied once, can ask again

Since `false` is ambiguous, we compare rationale **before and after** the
request. If it was `true` before and `false` after, the user just checked
"Don't ask again" → `permanentlyDenied`. See `classifyRuntimeDenial()` in
`packages/simple_permissions_android/lib/src/handlers/permission_handler.dart`.

## Adding a new permission

1. Add the sealed class in `packages/simple_permissions_platform_interface/lib/src/permissions/`
2. Register it in each platform's registry:
   - Android: `android_permission_registry.dart` — map type to handler
   - iOS: `ios_permission_registry.dart` — map type to identifier string
   - macOS: `macos_permission_registry.dart` — map type to identifier string
   - Web: `web_permission_registry.dart` — map type to browser permission name
3. Add the native handler (Swift handler class, or reuse existing)
4. Add tests in each platform's test file — the registry-alignment tests will
   catch missing registrations

## Adding a new platform

1. Create `packages/simple_permissions_<platform>/`
2. Extend `SimplePermissionsPlatform`
3. Implement `check`, `request`, `isSupported`, `openAppSettings`
4. Add `registerWith()` that sets `SimplePermissionsPlatform.instance`
5. Add to root `pubspec.yaml` dependencies and `flutter.plugin.platforms`
