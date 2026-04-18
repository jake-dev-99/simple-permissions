## 1.4.0

### Added — native Kotlin helpers module
- `PermissionGuards` object (in `packages/simple_permissions_android`) exposes a public Kotlin API that sibling plugins can call to **check** (read-only) whether a runtime permission is granted or whether the app holds a default-app role. Previously the only shared access-state API was Dart-side, forcing sibling plugins' Kotlin code to reach for `ContextCompat.checkSelfPermission(...)` / `RoleManager.isRoleHeld(...)` directly.
  - `PermissionGuards.isPermissionGranted(context, permission): Boolean`
  - `PermissionGuards.areAllPermissionsGranted(context, permissions): Boolean`
  - `PermissionGuards.isRoleHeld(context, roleId): Boolean`
  - Intentionally no request-side helpers — request flows surface UI and still belong behind the Dart API (`SimplePermissionsNative.instance.request(...)`).
- **Gradle reality (updated after attempting cross-plugin integration):** `implementation project(":simple_permissions_android")` only resolves when the consuming plugin lives in the same Gradle build. For sibling Flutter plugins in separate repos (simple-sms, simple-telephony, simple-query), the project path doesn't exist because Flutter's plugin system creates it inside the *final app's* settings.gradle, not inside other plugins' builds. Options: same-repo project dep, Gradle composite build (`includeBuild`), Maven publication, or keep using Android primitives in those plugins — see README for the tradeoff.
- Rule 2 (*"access state goes through simple-permissions"*) remains upheld at the **Dart API boundary** (request flows, observation, permission types). Native-side inline `ContextCompat.checkSelfPermission(...)` in sibling plugins is legitimate — it's a read-only OS query, not a permission request. `PermissionGuards` is the delegation path when same-repo or cross-repo Gradle is available.

## 1.3.0

- Added `PermissionObserver` — reactive view over a set of `Permission`s (including `AppRole`s like `DefaultSmsApp` / `DefaultDialerApp`) that re-queries on app resume and whenever `refresh()` is called. Exposed via `SimplePermissionsNative.instance.observe([...])`.
  - Consumers drive reactive UI (disable writes until role held, show "grant to continue" banners) from `PermissionObserver.stream` without writing their own lifecycle + poll loops.
  - Refresh triggers: `AppLifecycleState.resumed`, explicit `refresh()`, and the initial fetch at construction. Concurrent refresh calls are coalesced onto the in-flight future to keep result ordering predictable and avoid redundant platform work.
  - Platform failures are caught and routed onto the stream as errors rather than escaping as uncaught exceptions — important because the resume path fires refresh unawaited.
  - Lifecycle wiring is pluggable via `PermissionObserverLifecycle`; the default `WidgetsBindingLifecycle` hooks `WidgetsBinding`. Keeping this in the native (Flutter-aware) package — not the platform interface — so the platform interface stays Flutter-free.
  - Intentionally Dart-only — no native change needed. Matches platform reality (Android has no permission-change broadcast; re-query on resume is the accepted pattern).

## 1.2.0

- Added Apple example targets, Apple build validation, and Apple smoke-test coverage in CI.
- Refactored iOS and macOS native handlers into domain-specific Swift files with centralized registries.
- Split role-acquisition `Intention` presets from the default `texting` and `calling` runtime-permission presets.
- Consolidated Android Kotlin system-settings boilerplate into a data-driven dispatch pattern.
- Consolidated Dart `SystemSettingHandler` switch duplication via `SystemSettingType` enum methods.
- Removed duplicate background-location foreground check from `RuntimePermissionHandler` (orchestrator owns this logic).
- Expanded README with platform setup guides, `PermissionGrant` state table, `Intention` reference, and usage examples.
- Improved example app with Intention-based flows, batch requests, and denied-state handling.
- Made `Intention` const-constructible from user code (removed `UnmodifiableListView` wrapping).
- Added symmetric Kotlin test coverage for all system-setting request flows (overlay, install packages, schedule exact alarms).
- Added web platform support (`simple_permissions_web`) with browser Permissions API for camera, microphone, geolocation, and notifications.

## 1.1.0

- Added location accuracy API:
  - `checkLocationAccuracy()`
  - `LocationAccuracyStatus` (`precise`, `reduced`, `none`, `notApplicable`, `notAvailable`)
- Enforced Android background-location sequencing on API 30+:
  - `BackgroundLocation` requests now require prior foreground location grant.
  - If requested first, the plugin returns `PermissionGrant.denied` and does not invoke runtime request.
- Added Android permission types:
  - `BodySensorsBackground`
  - `ReadVoicemail`
  - `AddVoicemail`
  - `UwbRanging`
  - `AcceptHandover`

## 1.0.0

- Initial release of `simple_permissions_native`.
- Introduced federated plugin structure with:
  - `simple_permissions_platform_interface`
  - `simple_permissions_android`
  - `simple_permissions_ios`
- Added capability-based permission APIs for cross-platform checks and requests.
- Added detailed permission result modeling for richer status reporting.
- Included iOS privacy manifest support for App Store compliance.
