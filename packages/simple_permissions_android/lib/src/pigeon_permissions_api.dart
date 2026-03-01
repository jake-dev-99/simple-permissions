import 'permissions_api.dart';
import 'generated/permissions.g.dart';

/// Production [PermissionsApi] that delegates to the Pigeon-generated
/// [PermissionsHostApi] over platform channels.
class PigeonPermissionsApi implements PermissionsApi {
  const PigeonPermissionsApi(this._hostApi);

  final PermissionsHostApi _hostApi;

  @override
  Future<Map<String, bool>> checkPermissions(List<String> permissions) =>
      _hostApi.checkPermissions(permissions);

  @override
  Future<Map<String, bool>> requestPermissions(List<String> permissions) =>
      _hostApi.requestPermissions(permissions);

  @override
  Future<Map<String, bool>> shouldShowRequestPermissionRationale(
    List<String> permissions,
  ) =>
      _hostApi.shouldShowRequestPermissionRationale(permissions);

  @override
  Future<bool> isRoleHeld(String roleId) => _hostApi.isRoleHeld(roleId);

  @override
  Future<bool> requestRole(String roleId) => _hostApi.requestRole(roleId);

  @override
  Future<bool> isIgnoringBatteryOptimizations() =>
      _hostApi.isIgnoringBatteryOptimizations();

  @override
  Future<bool> requestIgnoreBatteryOptimizations() =>
      _hostApi.requestIgnoreBatteryOptimizations();

  @override
  Future<bool> openAppSettings() => _hostApi.openAppSettings();
}
