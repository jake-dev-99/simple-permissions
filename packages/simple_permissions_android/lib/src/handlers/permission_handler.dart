/// Abstract handler for a single Android permission or permission-like concept.
///
/// Each handler encapsulates the Android-specific logic for checking, requesting,
/// and determining support for one logical permission. The [AndroidPermissionRegistry]
/// maps sealed [Permission] types to concrete handler instances.
///
/// There are three handler flavors:
/// - [RuntimePermissionHandler] — standard `ActivityCompat.requestPermissions` flow
/// - [RoleHandler] — `RoleManager.requestRole` flow
/// - [SystemSettingHandler] — system settings intent flow (battery opt, etc.)
library;

import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

import '../permissions_api.dart';

part 'runtime_permission_handler.dart';
part 'role_handler.dart';
part 'system_setting_handler.dart';

/// Signature for a function that provides the current Android SDK version.
///
/// Injecting this as a callback rather than reading `Build.VERSION.SDK_INT`
/// directly makes handlers testable without Android framework mocks.
typedef SdkVersionProvider = int Function();

/// Determines whether a denied Android runtime permission is re-requestable
/// or permanently denied, using Android's rationale API as the signal.
///
/// ## How Android rationale works
///
/// `ActivityCompat.shouldShowRequestPermissionRationale(permission)` returns:
///
/// - **`false`** before the first request (user hasn't seen the dialog yet)
/// - **`true`** after the user denies once (system will show the dialog again)
/// - **`false`** after the user checks "Don't ask again" (permanently denied)
///
/// Because `false` means two different things (never asked vs. permanently
/// denied), we compare rationale **before** and **after** the request:
///
/// | Before | After  | Meaning                          | Result             |
/// |--------|--------|----------------------------------|--------------------|
/// | false  | false  | First denial (no "Don't ask")    | `denied`           |
/// | false  | true   | First denial (can ask again)     | `denied`           |
/// | true   | true   | Repeat denial (can ask again)    | `denied`           |
/// | true   | false  | User checked "Don't ask again"   | `permanentlyDenied`|
///
/// The key insight: rationale flipping from `true` → `false` is the only
/// reliable signal for "Don't ask again" on Android.
PermissionGrant classifyRuntimeDenial({
  required bool wasGrantedBeforeRequest,
  required bool isGrantedAfterRequest,
  required bool showedRationaleBeforeRequest,
  required bool shouldShowRationaleAfterRequest,
}) {
  if (wasGrantedBeforeRequest || isGrantedAfterRequest) {
    return PermissionGrant.granted;
  }
  if (shouldShowRationaleAfterRequest) {
    return PermissionGrant.denied;
  }
  if (showedRationaleBeforeRequest) {
    // Rationale was true before request, false after → user selected
    // "Don't ask again". This is the only way to detect permanent denial.
    return PermissionGrant.permanentlyDenied;
  }
  return PermissionGrant.denied;
}

/// Checks/requests a single Android permission or permission-like concept.
///
/// Handlers are stateless — they hold configuration (permission string, SDK
/// bounds) but no mutable state. The [PermissionsApi] transport and the
/// activity lifecycle are managed externally by [SimplePermissionsAndroid].
abstract class PermissionHandler {
  const PermissionHandler();

  /// Check whether this permission is currently granted.
  Future<PermissionGrant> check(PermissionsApi api);

  /// Request this permission from the user.
  ///
  /// Implementations must correctly distinguish between:
  /// - First-time denial → [PermissionGrant.denied]
  /// - "Don't ask again" denial → [PermissionGrant.permanentlyDenied]
  /// - Grant → [PermissionGrant.granted]
  Future<PermissionGrant> request(PermissionsApi api);

  /// Whether this permission exists on the running Android version.
  ///
  /// Returns `false` when the permission doesn't apply to this SDK level
  /// (e.g. `READ_MEDIA_IMAGES` on API 32, or `READ_EXTERNAL_STORAGE` on API 34).
  bool isSupported(SdkVersionProvider sdkVersion);
}
