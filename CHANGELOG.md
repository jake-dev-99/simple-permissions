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
