library;

import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

import 'src/generated/permissions_macos.g.dart';
import 'src/macos_permission_registry.dart';
import 'src/permissions_macos_api.dart';
import 'src/pigeon_permissions_macos_api.dart';

/// macOS implementation of [SimplePermissionsPlatform].
///
/// Uses an identifier-based Pigeon API to dispatch permission operations
/// to native Swift handlers. The [macosPermissionMapping] registry determines
/// which [Permission] types are applicable on macOS.
///
/// ## How it works
///
/// 1. The caller passes a [Permission] to [check] or [request].
/// 2. If it's a [VersionedPermission], [_resolve] picks the concrete
///    [Permission] for the current platform (macOS doesn't version-split
///    permissions the same way Android does, but the resolution still works).
/// 3. The [Permission.identifier] is looked up in the macOS registry.
/// 4. If registered, the identifier is sent to Swift via Pigeon.
/// 5. The wire string is parsed to a [PermissionGrant].
class SimplePermissionsMacos extends SimplePermissionsPlatform {
  SimplePermissionsMacos({
    PermissionsMacosApi? api,
  }) : _api = api ?? PigeonPermissionsMacosApi(PermissionsMacosHostApi());

  static void registerWith() {
    SimplePermissionsPlatform.instance = SimplePermissionsMacos();
  }

  final PermissionsMacosApi _api;

  // ===========================================================================
  // v2 API — Permission sealed classes
  // ===========================================================================

  @override
  Future<PermissionGrant> check(Permission permission) async {
    final resolved = _resolve(permission);
    final mapping = macosPermissionMapping(resolved.runtimeType);

    if (mapping == null) {
      return PermissionGrant.notApplicable;
    }

    final wire = await _api.checkPermission(mapping.identifier);
    return _permissionGrantFromWire(wire);
  }

  @override
  Future<PermissionGrant> request(Permission permission) async {
    final resolved = _resolve(permission);
    final mapping = macosPermissionMapping(resolved.runtimeType);

    if (mapping == null) {
      return PermissionGrant.notApplicable;
    }

    final wire = await _api.requestPermission(mapping.identifier);
    return _permissionGrantFromWire(wire);
  }

  @override
  bool isSupported(Permission permission) {
    final resolved = _resolve(permission);
    return isMacosPermissionRegistered(resolved.runtimeType);
  }

  @override
  Future<bool> openAppSettings() => _api.openAppSettings();

  // ===========================================================================
  // VersionedPermission resolution
  // ===========================================================================

  /// If [permission] is a [VersionedPermission], resolve it.
  ///
  /// macOS doesn't have the same API-level version splits as Android.
  /// We pick the first variant that has no minApiLevel constraint (macOS
  /// variants don't use API levels) or fall through to the first variant.
  Permission _resolve(Permission permission) {
    if (permission is! VersionedPermission) return permission;

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
