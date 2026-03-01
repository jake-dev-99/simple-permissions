import 'permission_grant.dart';
import 'permissions/permission.dart';

/// Parses Darwin wire values from native code into [PermissionGrant].
PermissionGrant permissionGrantFromDarwinWire(String? value) {
  switch (value) {
    case 'granted':
      return PermissionGrant.granted;
    case 'denied':
      return PermissionGrant.denied;
    case 'permanentlyDenied':
      return PermissionGrant.permanentlyDenied;
    case 'restricted':
      return PermissionGrant.restricted;
    case 'limited':
      return PermissionGrant.limited;
    case 'notAvailable':
      return PermissionGrant.notAvailable;
    case 'provisional':
      return PermissionGrant.provisional;
    case 'notApplicable':
    case null:
      return PermissionGrant.notApplicable;
    default:
      return PermissionGrant.denied;
  }
}

/// Resolves a [VersionedPermission] for Darwin platforms.
///
/// iOS/macOS variants do not rely on API level checks in the same way Android
/// does, so this chooses the first unconstrained variant, or falls back to the
/// first variant if all are constrained.
Permission resolveVersionedForDarwin(Permission permission) {
  if (permission is! VersionedPermission) return permission;

  for (final variant in permission.variants) {
    if (variant.minApiLevel == null && variant.maxApiLevel == null) {
      return variant.permission;
    }
  }
  if (permission.variants.isNotEmpty) {
    return permission.variants.first.permission;
  }
  return permission;
}
