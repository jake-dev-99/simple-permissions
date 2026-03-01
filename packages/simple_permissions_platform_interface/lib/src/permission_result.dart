import 'permissions/permission.dart';
import 'permission_grant.dart';

/// Result of checking or requesting multiple [Permission]s.
///
/// Provides convenience getters to inspect the aggregate grant state
/// without manually iterating the map.
class PermissionResult {
  const PermissionResult(this.permissions);

  /// Map from each requested [Permission] to its current [PermissionGrant].
  final Map<Permission, PermissionGrant> permissions;

  /// Whether all permissions are in a satisfactory state.
  ///
  /// Treats [PermissionGrant.granted], [PermissionGrant.limited],
  /// [PermissionGrant.notApplicable], and [PermissionGrant.provisional]
  /// as "satisfied".
  bool get isFullyGranted => permissions.values.every(_isSatisfied);

  /// Alias for [isFullyGranted].
  bool get isReady => isFullyGranted;

  /// Whether any permission has been denied (including permanently).
  bool get hasDenial => permissions.values.any(_isDenied);

  /// Whether any permission has been permanently denied.
  bool get hasPermanentDenial =>
      permissions.values.any((g) => g == PermissionGrant.permanentlyDenied);

  /// Whether the user must go to system settings to resolve a denial.
  bool get requiresSettings => hasPermanentDenial;

  /// All permissions that are in a denied state.
  List<Permission> get denied => permissions.entries
      .where((e) => _isDenied(e.value))
      .map((e) => e.key)
      .toList();

  /// Permissions specifically flagged as permanently denied.
  List<Permission> get permanentlyDenied => permissions.entries
      .where((e) => e.value == PermissionGrant.permanentlyDenied)
      .map((e) => e.key)
      .toList();

  /// Permissions that are not available on this OS version.
  List<Permission> get unavailable => permissions.entries
      .where((e) => e.value == PermissionGrant.notAvailable)
      .map((e) => e.key)
      .toList();

  /// Look up the grant state for a specific permission.
  PermissionGrant? operator [](Permission permission) =>
      permissions[permission];

  static bool _isSatisfied(PermissionGrant grant) =>
      grant == PermissionGrant.granted ||
      grant == PermissionGrant.limited ||
      grant == PermissionGrant.notApplicable ||
      grant == PermissionGrant.provisional;

  static bool _isDenied(PermissionGrant grant) =>
      grant == PermissionGrant.denied ||
      grant == PermissionGrant.permanentlyDenied ||
      grant == PermissionGrant.restricted;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionResult &&
        permissions.length == other.permissions.length &&
        permissions.entries.every(
          (entry) => other.permissions[entry.key] == entry.value,
        );
  }

  @override
  int get hashCode {
    final entries = permissions.entries.toList()
      ..sort((a, b) => a.key.identifier.compareTo(b.key.identifier));
    return Object.hashAll(
      entries.map((entry) => Object.hash(entry.key, entry.value)),
    );
  }

  @override
  String toString() => 'PermissionResult($permissions)';
}
