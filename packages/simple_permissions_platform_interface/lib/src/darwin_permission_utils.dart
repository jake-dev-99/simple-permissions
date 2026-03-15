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
/// does, so this chooses the first variant that is actually registered for the
/// current platform. If none are registered, the original versioned permission
/// is returned so the caller can classify it as unsupported.
Permission resolveVersionedForDarwin(
  Permission permission,
  bool Function(Type permissionType) isRegistered,
) {
  if (permission is! VersionedPermission) return permission;

  for (final variant in permission.variants) {
    if (isRegistered(variant.permission.runtimeType)) {
      return variant.permission;
    }
  }

  return permission;
}
