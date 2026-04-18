library;

import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';
import 'package:simple_permissions_platform_interface/darwin_permission_utils.dart';

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
    return performDarwinPermissionOperation(
      permission: permission,
      isRegistered: isIosPermissionRegistered,
      identifierForType: iosPermissionIdentifier,
      operation: _api.checkPermission,
    );
  }

  @override
  Future<PermissionGrant> request(Permission permission) async {
    return performDarwinPermissionOperation(
      permission: permission,
      isRegistered: isIosPermissionRegistered,
      identifierForType: iosPermissionIdentifier,
      operation: _api.requestPermission,
    );
  }

  @override
  Future<bool> isSupported(Permission permission) =>
      checkDarwinPermissionSupport(
        permission: permission,
        isRegistered: isIosPermissionRegistered,
        identifierForType: iosPermissionIdentifier,
        isSupported: _api.isSupported,
      );

  @override
  Future<bool> openAppSettings() => _api.openAppSettings();

  @override
  Future<LocationAccuracyStatus> checkLocationAccuracy() async {
    final wire = await _api.checkLocationAccuracy();
    return locationAccuracyStatusFromDarwinWire(wire);
  }
}
