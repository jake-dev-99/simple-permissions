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
library;

import 'package:flutter/foundation.dart';

import 'src/generated/permissions.g.dart';
import 'src/intention.dart';
import 'src/permission_result.dart';

export 'src/intention.dart';
export 'src/permission_result.dart';

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

    if (_isAndroid) {
      _hostApi = PermissionsHostApi();
    }

    _initialized = true;
  }

  /// Checks which permissions from the list are currently granted.
  ///
  /// Returns a map of permission string → granted status.
  Future<Map<String, bool>> checkPermissions(List<String> permissions) async {
    final hostApi = _ensureInitialized();
    final result = await hostApi.checkPermissions(permissions);
    return result.cast<String, bool>();
  }

  /// Requests the specified permissions from the user.
  ///
  /// Shows system permission dialogs. Returns map of permission → granted.
  Future<Map<String, bool>> requestPermissions(List<String> permissions) async {
    final hostApi = _ensureInitialized();
    final result = await hostApi.requestPermissions(permissions);
    return result.cast<String, bool>();
  }

  /// Checks whether an [Intention] is fully granted.
  ///
  /// For intentions requiring a role, this checks role + all permissions.
  /// For intentions without a role, this checks all permissions only.
  Future<bool> check(Intention intention) async {
    final result = await checkDetailed(intention);
    return result.isFullyGranted;
  }

  /// Requests everything needed for an [Intention] to be fully granted.
  ///
  /// For intentions requiring a role, role is requested first and permission
  /// requests are skipped if role request is denied.
  Future<bool> request(Intention intention) async {
    final result = await requestDetailed(intention);
    return result.isFullyGranted;
  }

  /// Detailed intention-level check with per-permission and role statuses.
  Future<PermissionResult> checkDetailed(Intention intention) async {
    final roleStatus = await _checkRoleStatus(intention.role);
    final permissionStatuses = await _checkPermissionStatuses(
      intention.permissions,
    );

    return PermissionResult(
      intention: intention,
      roleStatus: roleStatus,
      permissions: permissionStatuses,
    );
  }

  /// Detailed intention-level request with per-permission and role statuses.
  ///
  /// For intentions requiring a role, role is requested first.
  Future<PermissionResult> requestDetailed(Intention intention) async {
    final roleId = intention.role;
    PermissionStatus roleStatus = PermissionStatus.notRequired;

    if (roleId != null) {
      final hasRole = await isRoleHeld(roleId);
      if (hasRole) {
        roleStatus = PermissionStatus.granted;
      } else {
        final roleGranted = await requestRole(roleId);
        roleStatus =
            roleGranted ? PermissionStatus.granted : PermissionStatus.denied;
      }
    }

    final Map<String, PermissionStatus> permissionStatuses;
    if (roleStatus == PermissionStatus.denied) {
      // Avoid prompting for runtime permissions when role prerequisite is denied.
      permissionStatuses =
          await _checkPermissionStatuses(intention.permissions);
    } else {
      permissionStatuses = await _requestPermissionStatusesWithRationale(
        intention.permissions,
      );
    }

    return PermissionResult(
      intention: intention,
      roleStatus: roleStatus,
      permissions: permissionStatuses,
    );
  }

  /// Checks if the specified role is currently held by this app.
  ///
  /// Common roles:
  /// - `android.app.role.SMS` - Default SMS app
  /// - `android.app.role.DIALER` - Default phone app
  Future<bool> isRoleHeld(String roleId) async {
    return _ensureInitialized().isRoleHeld(roleId);
  }

  /// Requests the specified role from the user.
  ///
  /// Shows system role request dialog. Returns true if granted.
  Future<bool> requestRole(String roleId) async {
    return _ensureInitialized().requestRole(roleId);
  }

  /// Checks if the app is exempt from battery optimization.
  ///
  /// Battery optimization exemption is important for SMS apps to ensure
  /// reliable message delivery when the phone is idle or in Doze mode.
  Future<bool> isIgnoringBatteryOptimizations() async {
    return _ensureInitialized().isIgnoringBatteryOptimizations();
  }

  /// Requests exemption from battery optimization.
  ///
  /// This is recommended for SMS apps to ensure messages are delivered
  /// reliably when the phone is idle. Shows a system dialog explaining
  /// the request to the user.
  ///
  /// Returns true if the exemption was granted.
  Future<bool> requestBatteryOptimizationExemption() async {
    return _ensureInitialized().requestIgnoreBatteryOptimizations();
  }

  /// Returns Android rationale visibility for each permission.
  ///
  /// A `false` value after a user denial usually indicates the permission is
  /// permanently denied and settings navigation is required.
  Future<Map<String, bool>> shouldShowRequestPermissionRationale(
    List<String> permissions,
  ) async {
    return _ensureInitialized().shouldShowRequestPermissionRationale(
      permissions,
    );
  }

  /// Convenience wrapper to check rationale visibility for any permission
  /// in an [Intention].
  Future<bool> shouldShowRationale(Intention intention) async {
    final rationale = await shouldShowRequestPermissionRationale(
      intention.permissions,
    );
    return rationale.values.any((value) => value);
  }

  /// Opens this app's system settings screen.
  Future<bool> openAppSettings() async {
    return _ensureInitialized().openAppSettings();
  }

  PermissionsHostApi _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'SimplePermissions is not initialized. Call '
        'SimplePermissions.initialize() before using the API.',
      );
    }

    if (!_isAndroid || _hostApi == null) {
      throw UnsupportedError(
        'simple_permissions currently supports Android only.',
      );
    }

    return _hostApi!;
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<PermissionStatus> _checkRoleStatus(String? roleId) async {
    if (roleId == null) return PermissionStatus.notRequired;
    final hasRole = await isRoleHeld(roleId);
    return hasRole ? PermissionStatus.granted : PermissionStatus.denied;
  }

  Future<Map<String, PermissionStatus>> _checkPermissionStatuses(
    List<String> permissions,
  ) async {
    final result = await checkPermissions(permissions);
    return _toPermissionStatusMap(result);
  }

  Future<Map<String, PermissionStatus>> _requestPermissionStatusesWithRationale(
    List<String> permissions,
  ) async {
    final requested = await requestPermissions(permissions);
    final deniedPermissions = requested.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();

    if (deniedPermissions.isEmpty) {
      return _toPermissionStatusMap(requested);
    }

    final rationale = await shouldShowRequestPermissionRationale(
      deniedPermissions,
    );

    final statuses = <String, PermissionStatus>{};
    for (final entry in requested.entries) {
      if (entry.value) {
        statuses[entry.key] = PermissionStatus.granted;
      } else {
        final shouldShow = rationale[entry.key] ?? false;
        statuses[entry.key] = shouldShow
            ? PermissionStatus.denied
            : PermissionStatus.permanentlyDenied;
      }
    }
    return statuses;
  }

  Map<String, PermissionStatus> _toPermissionStatusMap(
    Map<String, bool> permissions,
  ) {
    final statuses = <String, PermissionStatus>{};
    for (final entry in permissions.entries) {
      statuses[entry.key] =
          entry.value ? PermissionStatus.granted : PermissionStatus.denied;
    }
    return statuses;
  }
}
