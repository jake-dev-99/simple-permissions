library;

import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

import 'src/generated/permissions_ios.g.dart';
import 'src/ios_permission_registry.dart';
import 'src/permissions_ios_api.dart';
import 'src/pigeon_permissions_ios_api.dart';

/// iOS implementation of [SimplePermissionsPlatform].
///
/// Uses an identifier-based Pigeon API to dispatch permission operations
/// to native Swift handlers. The [iosPermissionMapping] registry determines
/// which [Permission] types are applicable on iOS.
///
/// ## How it works
///
/// 1. The caller passes a [Permission] to [check] or [request].
/// 2. If it's a [VersionedPermission], [_resolve] picks the concrete
///    [Permission] for the current platform (iOS doesn't version-split
///    permissions the same way Android does, but the resolution still works).
/// 3. The [Permission.identifier] is looked up in the iOS registry.
/// 4. If registered, the identifier is sent to Swift via Pigeon.
/// 5. The wire string is parsed to a [PermissionGrant].
class SimplePermissionsIos extends SimplePermissionsPlatform {
  SimplePermissionsIos({
    PermissionsIosApi? api,
  }) : _api = api ?? PigeonPermissionsIosApi(PermissionsIosHostApi());

  static void registerWith() {
    SimplePermissionsPlatform.instance = SimplePermissionsIos();
  }

  final PermissionsIosApi _api;

  // ===========================================================================
  // v2 API — Permission sealed classes
  // ===========================================================================

  @override
  Future<PermissionGrant> check(Permission permission) async {
    final resolved = _resolve(permission);
    final mapping = iosPermissionMapping(resolved.runtimeType);

    if (mapping == null) {
      return PermissionGrant.notApplicable;
    }

    final wire = await _api.checkPermission(mapping.identifier);
    return _permissionGrantFromWire(wire);
  }

  @override
  Future<PermissionGrant> request(Permission permission) async {
    final resolved = _resolve(permission);
    final mapping = iosPermissionMapping(resolved.runtimeType);

    if (mapping == null) {
      return PermissionGrant.notApplicable;
    }

    final wire = await _api.requestPermission(mapping.identifier);
    return _permissionGrantFromWire(wire);
  }

  @override
  bool isSupported(Permission permission) {
    final resolved = _resolve(permission);
    return isIosPermissionRegistered(resolved.runtimeType);
  }

  @override
  Future<bool> openAppSettings() => _api.openAppSettings();

  // ===========================================================================
  // VersionedPermission resolution
  // ===========================================================================

  /// If [permission] is a [VersionedPermission], resolve it.
  ///
  /// iOS doesn't have the same API-level version splits as Android, but
  /// [VersionedPermission.images()] for example should still resolve to
  /// [ReadMediaImages] since iOS uses PHPhotoLibrary for that concept.
  /// We pick the first variant that has no minApiLevel constraint (iOS
  /// variants don't use API levels) or fall through to the first variant.
  Permission _resolve(Permission permission) {
    if (permission is! VersionedPermission) return permission;

    // For iOS, pick the first variant without API level constraints,
    // or the first variant overall. The iOS registry will then determine
    // if that permission type is supported.
    for (final variant in permission.variants) {
      if (variant.minApiLevel == null && variant.maxApiLevel == null) {
        return variant.permission;
      }
    }
    // Fall back to the first variant.
    if (permission.variants.isNotEmpty) {
      return permission.variants.first.permission;
    }
    return permission;
  }

  // ===========================================================================
  // Wire parsing
  // ===========================================================================

  PermissionGrant _permissionGrantFromWire(String? value) {
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
}
