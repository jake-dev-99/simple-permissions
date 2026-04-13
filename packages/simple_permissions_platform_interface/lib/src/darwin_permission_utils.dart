import 'permission_grant.dart';
import 'location_accuracy_status.dart';
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

typedef DarwinIdentifierLookup = String? Function(Type permissionType);

Future<PermissionGrant> performDarwinPermissionOperation({
  required Permission permission,
  required bool Function(Type permissionType) isRegistered,
  required DarwinIdentifierLookup identifierForType,
  required Future<String> Function(String identifier) operation,
}) async {
  final resolved = resolveVersionedForDarwin(permission, isRegistered);
  final identifier = identifierForType(resolved.runtimeType);
  if (identifier == null) {
    return PermissionGrant.notApplicable;
  }

  final wire = await operation(identifier);
  return permissionGrantFromDarwinWire(wire);
}

Future<bool> checkDarwinPermissionSupport({
  required Permission permission,
  required bool Function(Type permissionType) isRegistered,
  required DarwinIdentifierLookup identifierForType,
  required Future<bool> Function(String identifier) isSupported,
}) async {
  final resolved = resolveVersionedForDarwin(permission, isRegistered);
  final identifier = identifierForType(resolved.runtimeType);
  if (identifier == null) {
    return false;
  }
  return isSupported(identifier);
}

LocationAccuracyStatus locationAccuracyStatusFromDarwinWire(String? wire) {
  switch (wire) {
    case 'precise':
      return LocationAccuracyStatus.precise;
    case 'reduced':
      return LocationAccuracyStatus.reduced;
    case 'none':
      return LocationAccuracyStatus.none;
    case 'notAvailable':
      return LocationAccuracyStatus.notAvailable;
    case 'notApplicable':
    case null:
      return LocationAccuracyStatus.notApplicable;
    default:
      return LocationAccuracyStatus.notApplicable;
  }
}
