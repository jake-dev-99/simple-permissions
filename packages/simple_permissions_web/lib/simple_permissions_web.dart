library;

import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

// Conditional import: on web (where dart:js_interop exists), this resolves to
// api_factory_web.dart which returns a real BrowserPermissionsApi backed by
// browser JS APIs. On the Dart VM (unit tests, native platforms), it resolves
// to api_factory_stub.dart which throws UnsupportedError — this is fine because
// tests inject a mock via the constructor and never call createBrowserApi().
import 'src/api_factory_stub.dart'
    if (dart.library.js_interop) 'src/api_factory_web.dart';
import 'src/web_permission_registry.dart';
import 'src/web_permissions_api_base.dart';


/// Web implementation of [SimplePermissionsPlatform].
///
/// Uses the browser Permissions API (`navigator.permissions.query`) to check
/// permission state, and individual request APIs (`getUserMedia`,
/// `Notification.requestPermission`, `getCurrentPosition`) to trigger prompts.
///
/// ## Supported permissions
///
/// - [CameraAccess] → `camera`
/// - [RecordAudio] → `microphone`
/// - [FineLocation] / [CoarseLocation] → `geolocation`
/// - [PostNotifications] → `notifications`
///
/// All other permission types return [PermissionGrant.notApplicable].
class SimplePermissionsWeb extends SimplePermissionsPlatform {
  SimplePermissionsWeb({WebPermissionsApi? api})
      : _api = api ?? createBrowserApi();

  static void registerWith([Object? registrar]) {
    SimplePermissionsPlatform.instance = SimplePermissionsWeb();
  }

  final WebPermissionsApi _api;

  @override
  Future<PermissionGrant> check(Permission permission) async {
    final resolved = _resolveForWeb(permission);
    final webName = webPermissionIdentifier(resolved.runtimeType);
    if (webName == null) return PermissionGrant.notApplicable;

    final state = await _api.queryPermission(webName);
    return _mapBrowserState(state);
  }

  @override
  Future<PermissionGrant> request(Permission permission) async {
    final resolved = _resolveForWeb(permission);
    final webName = webPermissionIdentifier(resolved.runtimeType);
    if (webName == null) return PermissionGrant.notApplicable;

    // Check current state first — avoid re-requesting if already decided.
    final currentState = await _api.queryPermission(webName);
    if (currentState == 'granted') return PermissionGrant.granted;
    if (currentState == 'denied') return PermissionGrant.permanentlyDenied;

    // Trigger the browser-specific request flow.
    final granted = await _requestByType(resolved);
    return granted ? PermissionGrant.granted : PermissionGrant.denied;
  }

  @override
  Future<bool> isSupported(Permission permission) async {
    final resolved = _resolveForWeb(permission);
    return isWebPermissionRegistered(resolved.runtimeType);
  }

  @override
  Future<bool> openAppSettings() => _api.openAppSettings();

  @override
  Future<LocationAccuracyStatus> checkLocationAccuracy() async {
    // Web geolocation doesn't expose precision levels.
    final state = await _api.queryPermission('geolocation');
    if (state == 'granted') return LocationAccuracyStatus.precise;
    return LocationAccuracyStatus.notApplicable;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Resolve [VersionedPermission] for web by picking the first variant
  /// that is registered in the web registry.
  Permission _resolveForWeb(Permission permission) {
    if (permission is! VersionedPermission) return permission;

    for (final variant in permission.variants) {
      if (isWebPermissionRegistered(variant.permission.runtimeType)) {
        return variant.permission;
      }
    }
    return permission;
  }

  /// Map browser `PermissionStatus.state` to [PermissionGrant].
  static PermissionGrant _mapBrowserState(String? state) {
    switch (state) {
      case 'granted':
        return PermissionGrant.granted;
      case 'denied':
        // Browser "denied" means the user must change it in site settings —
        // equivalent to permanentlyDenied on mobile.
        return PermissionGrant.permanentlyDenied;
      case 'prompt':
        // Not yet asked — re-requestable.
        return PermissionGrant.denied;
      default:
        // API unavailable or unexpected value.
        return PermissionGrant.notApplicable;
    }
  }

  /// Dispatch the actual browser request based on permission type.
  Future<bool> _requestByType(Permission permission) async {
    return switch (permission) {
      CameraAccess() => _api.requestCamera(),
      RecordAudio() => _api.requestMicrophone(),
      FineLocation() || CoarseLocation() => _api.requestGeolocation(),
      PostNotifications() => _requestNotifications(),
      _ => Future.value(false),
    };
  }

  Future<bool> _requestNotifications() async {
    final result = await _api.requestNotifications();
    return result == 'granted';
  }
}
