## 1.6.0

### Added — runtime gate helpers (Dart facade)

- `SimplePermissionsNative.instance.ensureGranted(Permission)` — checks first; requests only if not satisfied and not in a terminal state (permanentlyDenied / restricted / notApplicable / notAvailable). Returns the post-request grant so the caller can branch on denial mode.
- `ensureGrantedAll(List<Permission>)` / `ensureIntention(Intention)` — batch forms. Only the prompt-worthy permissions are forwarded to `requestAll`; the rest are pulled from the initial check snapshot. Avoids re-prompting permissions the user has permanently denied.
- `guard<T>(Permission, Future<T> Function())` / `guardAll` / `guardIntention` — run-with sugar. Returns the action's value if granted, `null` otherwise. Use `ensureGranted` when you need to distinguish *why* a guard returned null (e.g. to route to `openAppSettings`).
- All new methods compose existing `check` / `request` / `checkAll` / `requestAll` — no platform-interface changes.

### Added — Android native assertions (`PermissionGuards`)

- `PermissionGuards.requirePermissionGranted(context, permission)` — throws `PermissionDeniedException` (extends `SecurityException`) if the permission isn't granted. Defense-in-depth for sibling plugins whose Kotlin methods call framework APIs that themselves throw on missing permissions (e.g. `TelecomManager.placeCall`). Produces a clear library-specific error instead of the framework's opaque `SecurityException`.
- `requireAnyPermissionGranted(context, permissions)` — mirror for `anyOf` framework contracts (e.g. `CALL_PHONE` *or* `MANAGE_OWN_CALLS`).
- `requireAllPermissionsGranted(context, permissions)` — mirror of `areAllPermissionsGranted`; `.deniedPermissions` on the exception lists only the missing subset.
- `requireRoleHeld(context, roleId)` — throw-if-missing for default-app roles.
- `PermissionDeniedException.deniedPermissions: List<String>` — so callers can surface precise error UI.
- These do **not** satisfy Android lint's `MissingPermission` check; that remains `@RequiresPermission(anyOf = [...])`'s job. The two compose.

### Added — `PermissionGrantStatus` extension

- `PermissionGrant.isSatisfied` / `isDenied` / `isUnsupported` / `isTerminal` — promoted from private helpers inside `PermissionResult`. Used by the new gate helpers and `PermissionResult` so the "what counts as satisfied/denied/terminal" definition lives in one place.

### Added — integration guide

- `docs/INTEGRATION_GUIDE.md` codifies the three-layer responsibility model (client app decides / sibling-plugin Dart declares / sibling-plugin native asserts), the Android lint cookbook (`@RequiresPermission` + `PermissionGuards.require*`), the `BIND_*` manifest pattern, and an iOS parity note. Includes a shippable-plugin checklist so new members of the `simple_*` family land on the same pattern.

### Toolchain

- Android Java / Kotlin JVM target raised to 21 (was 17 for the plugin, 11 for the example). Aligns every sub-project so `javac`, Kotlin, and AGP agree.
- `compileSdk` 35 → 36 in the plugin; example app hardcodes `compileSdk = 36` so it doesn't drift with `flutter.compileSdkVersion`.
- Example NDK 27.0.12077973 → 30.0.14904198.
- Gradle wrapper 8.11.1 → 8.13.
- Kotlin plugin 1.8.22 → 2.1.21 (1.8.x tops out at JVM target 19; Flutter tooling deprecates <2.1.0).

## 1.5.0

### Fixed — correctness

- **Web geolocation double-settle**: `BrowserPermissionsApi.requestGeolocation` now uses explicit single-shot discipline (a `settled` flag and tiny `settle()` helper). The browser contract is success XOR error, but a misbehaving or duplicated callback used to throw inside the JS-interop shim where the error was invisible.
- **`PermissionObserver` leak when `dispose()` is forgotten**: the lifecycle adapter now holds a `WeakReference` to the observer instead of pinning it, and a `Finalizer` registered at construction runs a detach/close cleanup token if the observer is garbage-collected without explicit disposal. Debug builds log a one-line warning so the missing `dispose()` is visible during development.
- **`VersionedPermission` silent fallthrough on Android**: `_resolve()` now returns `Permission?` and every call site (check/request/checkAll/requestAll/isSupported) treats `null` as `PermissionGrant.notAvailable`. Previously an out-of-range SDK would fall through to a registry miss and classify the permission as `notApplicable`.

### Added — tests & CI hygiene

- Observer suite covers dispose ↔ in-flight refresh races: dispose-during-refresh, resume-after-dispose, and late-error-after-dispose interleavings.
- Analyzer elevated across root + every sub-package: `unawaited_futures`, `unused_import`, `unused_local_variable`, `dead_code`, `invalid_null_aware_operator` are errors. Added `prefer_null_aware_operators`, `cancel_subscriptions`, `close_sinks`, `test_types_in_equals`, `throw_in_finally`, `unnecessary_await_in_return`; root adds `use_build_context_synchronously` and `avoid_slow_async_io`.

### Refactored

- Browser permission state strings (`granted` / `denied` / `prompt`) extracted to `browser_permission_state.dart` constants.
- Web `BrowserPermissionsApi` `catch (_)` sites log to `debugPrint` in debug mode; production return values are unchanged.
- Android registry field drops gratuitous `late` — the initializer is cheap (const-built map) and every code path touches it.

### Docs

- `SimplePermissionsWeb` class doc now documents the observer refresh cadence on web (tab-focus refreshes; no `PermissionStatus.onchange` wiring yet).

## 1.4.0

### Added — native Kotlin helpers module
- `PermissionGuards` object (in `packages/simple_permissions_android`) exposes a public Kotlin API that sibling plugins can call to **check** (read-only) whether a runtime permission is granted or whether the app holds a default-app role. Previously the only shared access-state API was Dart-side, forcing sibling plugins' Kotlin code to reach for `ContextCompat.checkSelfPermission(...)` / `RoleManager.isRoleHeld(...)` directly.
  - `PermissionGuards.isPermissionGranted(context, permission): Boolean`
  - `PermissionGuards.areAllPermissionsGranted(context, permissions): Boolean`
  - `PermissionGuards.isRoleHeld(context, roleId): Boolean`
  - Intentionally no request-side helpers — request flows surface UI and still belong behind the Dart API (`SimplePermissionsNative.instance.request(...)`).
- **Gradle wiring (verified working cross-repo):** two-line setup in any consuming plugin — add `simple_permissions_native` to its root `pubspec.yaml`, then `implementation(project(":simple_permissions_android"))` in its `android/build.gradle[.kts]`. Flutter's plugin-loader walks the pubspec graph at app-build time and synthesizes Gradle project entries for every federated plugin's Android module into the final app's build, so `:simple_permissions_android` exists alongside the consuming plugin and the project ref resolves. Demonstrated in simple-sms PR #19.
- **Gotcha for local path-dep workflows:** if the consuming plugin's example app uses `dependency_overrides` for `simple_permissions_native`, override each federated platform package (`simple_permissions_android`, `simple_permissions_platform_interface`, …) explicitly too — the plugin-loader registers Gradle paths per platform package, and a facade-only override leaves `:simple_permissions_android` resolving to pub.dev, which manifests as "unresolved reference" on any new Kotlin API. See README for the full snippet.
- Rule 2 (*"access state goes through simple-permissions"*) is upheld at the **Dart API boundary** (request flows, observation, permission types) regardless. `PermissionGuards` is the cleanup path for plugins that want to eliminate inline `ContextCompat.checkSelfPermission(...)` and route native reads through the vocabulary owner too; plugins that can't or don't want to add the dep keep inline primitives fine.

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
