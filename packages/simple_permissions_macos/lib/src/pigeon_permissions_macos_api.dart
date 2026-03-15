import 'generated/permissions_macos.g.dart';
import 'permissions_macos_api.dart';

/// Production implementation of [PermissionsMacosApi] that delegates
/// to the Pigeon-generated [PermissionsMacosHostApi].
class PigeonPermissionsMacosApi implements PermissionsMacosApi {
  PigeonPermissionsMacosApi(this._hostApi);

  final PermissionsMacosHostApi _hostApi;

  @override
  Future<String> checkPermission(String identifier) =>
      _hostApi.checkPermission(identifier);

  @override
  Future<String> requestPermission(String identifier) =>
      _hostApi.requestPermission(identifier);

  @override
  Future<bool> openAppSettings() => _hostApi.openAppSettings();

  @override
  Future<String> checkLocationAccuracy() => _hostApi.checkLocationAccuracy();
}
