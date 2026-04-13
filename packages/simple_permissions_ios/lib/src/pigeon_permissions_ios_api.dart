import 'permissions_ios_api.dart';
import 'generated/permissions_ios.g.dart';

/// Production [PermissionsIosApi] that delegates to the Pigeon-generated
/// [PermissionsIosHostApi] over platform channels.
class PigeonPermissionsIosApi implements PermissionsIosApi {
  const PigeonPermissionsIosApi(this._hostApi);

  final PermissionsIosHostApi _hostApi;

  @override
  Future<String> checkPermission(String identifier) =>
      _hostApi.checkPermission(identifier);

  @override
  Future<String> requestPermission(String identifier) =>
      _hostApi.requestPermission(identifier);

  @override
  Future<bool> isSupported(String identifier) => _hostApi.isSupported(identifier);

  @override
  Future<bool> openAppSettings() => _hostApi.openAppSettings();

  @override
  Future<String> checkLocationAccuracy() => _hostApi.checkLocationAccuracy();
}
