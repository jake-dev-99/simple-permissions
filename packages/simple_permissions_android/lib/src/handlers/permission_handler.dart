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

import 'dart:developer' as developer;

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
