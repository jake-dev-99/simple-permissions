/// Unified permission handling for Flutter apps.
///
/// Provides a high-level API for managing Android runtime permissions,
/// app roles (SMS, Dialer), and battery optimization exemption.
///
/// ## Usage
///
/// ```dart
/// // Initialize (call once at app startup)
/// await SimplePermissions.initialize();
///
/// // Check permissions
/// final status = await SimplePermissions.instance.checkPermissions(
///   Intention.texting.permissions,
/// );
///
/// // Request a role
/// final granted = await SimplePermissions.instance.requestRole(
///   Intention.texting.role!,
/// );
/// ```
library simple_permissions;

import 'dart:io';

import 'src/generated/permissions.g.dart';

export 'src/intention.dart';

/// High-level facade for permission operations.
///
/// Use [SimplePermissions.instance] to access the singleton after calling
/// [SimplePermissions.initialize].
class SimplePermissions {
  SimplePermissions._();

  static final SimplePermissions instance = SimplePermissions._();
  static PermissionsHostApi? _hostApi;
  static bool _initialized = false;

  /// Initializes the permission system.
  ///
  /// Must be called before using any permission methods.
  /// Safe to call multiple times - subsequent calls are no-ops.
  static Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      _hostApi = PermissionsHostApi();
    }

    _initialized = true;
  }

  /// Checks which permissions from the list are currently granted.
  ///
  /// Returns a map of permission string → granted status.
  Future<Map<String, bool>> checkPermissions(List<String> permissions) async {
    if (!Platform.isAndroid) {
      return {for (var p in permissions) p: true};
    }

    final result = await _hostApi!.checkPermissions(permissions);
    return result.cast<String, bool>();
  }

  /// Requests the specified permissions from the user.
  ///
  /// Shows system permission dialogs. Returns map of permission → granted.
  Future<Map<String, bool>> requestPermissions(List<String> permissions) async {
    if (!Platform.isAndroid) {
      return {for (var p in permissions) p: true};
    }

    final result = await _hostApi!.requestPermissions(permissions);
    return result.cast<String, bool>();
  }

  /// Checks if the specified role is currently held by this app.
  ///
  /// Common roles:
  /// - `android.app.role.SMS` - Default SMS app
  /// - `android.app.role.DIALER` - Default phone app
  Future<bool> isRoleHeld(String roleId) async {
    if (!Platform.isAndroid) return true;
    return _hostApi!.isRoleHeld(roleId);
  }

  /// Requests the specified role from the user.
  ///
  /// Shows system role request dialog. Returns true if granted.
  Future<bool> requestRole(String roleId) async {
    if (!Platform.isAndroid) return true;
    return _hostApi!.requestRole(roleId);
  }

  /// Checks if the app is exempt from battery optimization.
  ///
  /// Battery optimization exemption is important for SMS apps to ensure
  /// reliable message delivery when the phone is idle or in Doze mode.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    return _hostApi!.isIgnoringBatteryOptimizations();
  }

  /// Requests exemption from battery optimization.
  ///
  /// This is recommended for SMS apps to ensure messages are delivered
  /// reliably when the phone is idle. Shows a system dialog explaining
  /// the request to the user.
  ///
  /// Returns true if the exemption was granted.
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;
    return _hostApi!.requestIgnoreBatteryOptimizations();
  }
}
