
# 1.0.0

## Breaking Changes

- **Federated plugin architecture**: Restructured as a federated plugin with
  `simple_permissions_platform_interface`, `simple_permissions_android`, and
  `simple_permissions_ios` sub-packages.
- **Capability-based API is now primary**: `checkCapability()` /
  `requestCapability()` using `PermissionCapability` enum is the recommended
  cross-platform API. The `Intention`-level convenience methods (`check()`,
  `request()`) now route through capabilities internally.
- **`CapabilityResult`** replaces `PermissionResult` for cross-platform
  detailed permission checks via `checkDetailedCapabilities()` and
  `requestDetailedCapabilities()`.

## Deprecations

- `checkPermissions(List<String>)` — use `checkCapability()` instead.
- `requestPermissions(List<String>)` — use `requestCapability()` instead.
- `isRoleHeld(String)` / `requestRole(String)` — use capability equivalents.
- `isIgnoringBatteryOptimizations()` / `requestBatteryOptimizationExemption()`
  — use `checkCapability(canBypassBatteryOptimizations)`.
- `shouldShowRequestPermissionRationale()` / `shouldShowRationale()` —
  Android-only; `requestCapability()` returns `permanentlyDenied` directly.
- `checkDetailed(Intention)` / `requestDetailed(Intention)` — use
  `checkDetailedCapabilities()` / `requestDetailedCapabilities()`.

## Added

- **iOS platform support**: Contacts, Notifications, Photo Library (images/
  video), and Microphone permissions with native Swift handlers.
- `PermissionCapability` enum (16 capabilities) for platform-agnostic
  permission modeling.
- `PermissionGrant` enum (`granted`, `denied`, `permanentlyDenied`,
  `notApplicable`) for per-capability results.
- `CapabilityResult` type for rich cross-platform permission outcomes.
- iOS Privacy Manifest (`PrivacyInfo.xcprivacy`) for App Store compliance.
- GitHub Actions CI workflow.

## Changed

- `Intention.check()` / `Intention.request()` now route through
  `checkCapability` / `requestCapability` using `intention.capabilities`,
  making them work on both Android and iOS.
- Noop platform (unsupported platforms) now returns `PermissionGrant.granted`
  for all capabilities, consistent with legacy behavior.
- Pigeon codegen relocated to `packages/simple_permissions_android/`.
- Removed dead root-level `android/` directory.

## 0.2.0

- Initial Android release.
- Added runtime permission check/request APIs.
- Added role check/request APIs for SMS and Dialer roles.
- Added battery optimization status/request APIs.
- Added safety guardrails for initialization and unsupported platforms.
- Added rich intention result model (`PermissionStatus`, `PermissionResult`)
  with `checkDetailed` and `requestDetailed`.
- Added rationale and recovery APIs:
  `shouldShowRequestPermissionRationale`, `shouldShowRationale`, and
  `openAppSettings`.
- Added Android concurrency guardrails: overlapping request calls now fail
  fast with `PlatformException(code: "request-in-progress")` instead of
  clobbering pending callbacks.
- Normalized Android API-level permission semantics for file/media and
  notifications to avoid false-denied results across API 31/33+.
- Added Android 31/33/34+ integration-test matrix scenarios and README
  commands for reproducible API-level validation.
- Removed unused `plugin_platform_interface` dependency.
