import 'intention.dart';

/// Status for a role or runtime permission.
enum PermissionStatus {
  /// Granted and ready to use.
  granted,

  /// Not granted.
  denied,

  /// Permanently denied and requires opening system settings.
  ///
  /// Note: this is reserved for future rationale/settings integration.
  permanentlyDenied,

  /// Not applicable (for example, intentions without a role).
  notRequired,
}

/// Rich intention-level permission outcome.
class PermissionResult {
  const PermissionResult({
    required this.intention,
    required this.roleStatus,
    required this.permissions,
  });

  /// Intention this result belongs to.
  final Intention intention;

  /// Role result for the intention.
  ///
  /// Uses [PermissionStatus.notRequired] when no role is needed.
  final PermissionStatus roleStatus;

  /// Per-permission status map (`android.permission.*` -> status).
  final Map<String, PermissionStatus> permissions;

  /// True when every permission in [permissions] is granted.
  bool get allPermissionsGranted =>
      permissions.values.every((status) => status == PermissionStatus.granted);

  /// True when role is granted or not required.
  bool get isRoleGranted =>
      roleStatus == PermissionStatus.granted ||
      roleStatus == PermissionStatus.notRequired;

  /// True when role and all permissions are granted.
  bool get isFullyGranted => isRoleGranted && allPermissionsGranted;

  /// True when any status indicates permanent denial.
  ///
  /// This will become active once rationale/settings checks are wired in.
  bool get hasPermanentDenial {
    if (roleStatus == PermissionStatus.permanentlyDenied) return true;
    return permissions.values.any(
      (status) => status == PermissionStatus.permanentlyDenied,
    );
  }

  /// Convenience flag for "user must go to system settings".
  bool get requiresSettings => hasPermanentDenial;
}
