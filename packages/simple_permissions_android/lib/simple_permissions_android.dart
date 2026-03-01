library;

import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

import 'src/android_permission_registry.dart';
import 'src/generated/permissions.g.dart';
import 'src/handlers/permission_handler.dart';
import 'src/permissions_api.dart';
import 'src/pigeon_permissions_api.dart';

/// Android implementation of [SimplePermissionsPlatform].
///
/// Uses a handler registry ([buildAndroidPermissionRegistry]) to map sealed
/// [Permission] types to Android-specific check/request logic. Handlers
/// communicate with the native side through the Pigeon [PermissionsHostApi].
///
/// ## How it works
///
/// 1. The caller passes a [Permission] to [check] or [request].
/// 2. If it's a [VersionedPermission], [_resolveVersioned] picks the
///    concrete [Permission] whose API range matches the running device.
/// 3. The concrete [Permission]'s `runtimeType` is looked up in the registry.
/// 4. The handler's [PermissionHandler.check]/[request] method is called.
/// 5. The result is returned as a [PermissionGrant].
///
/// ## SDK version
///
/// The running SDK version is injected via [_sdkVersion] (defaults to
/// reading from the native side on first use). Tests can override this
/// with an [sdkVersionOverride] parameter.
class SimplePermissionsAndroid extends SimplePermissionsPlatform {
  SimplePermissionsAndroid({
    PermissionsApi? api,
    SdkVersionProvider? sdkVersionOverride,
  })  : _api = api ?? PigeonPermissionsApi(PermissionsHostApi()),
        _sdkVersionOverride = sdkVersionOverride;

  static void registerWith() {
    SimplePermissionsPlatform.instance = SimplePermissionsAndroid();
  }

  final PermissionsApi _api;
  final SdkVersionProvider? _sdkVersionOverride;

  /// Lazily-built handler registry.
  late final Map<Type, PermissionHandler> _registry =
      buildAndroidPermissionRegistry();

  // For caching the SDK version obtained from the native side.
  int? _cachedSdkVersion;

  /// Returns the current Android SDK version.
  int _getSdkVersion() {
    if (_sdkVersionOverride != null) return _sdkVersionOverride();
    // TODO(Phase 2 follow-up): Add a Pigeon method to read Build.VERSION.SDK_INT.
    // For now, return the cached value or a safe default. The native-side
    // `isPermissionApplicable` in PermissionsHostApiImpl.kt already handles
    // version checks, so this is primarily for Dart-side `isSupported()`.
    return _cachedSdkVersion ?? 34; // Default to API 34 (most common target)
  }

  /// [SdkVersionProvider] callback for handler consumption.
  late final SdkVersionProvider _sdkVersion = _getSdkVersion;

  // ===========================================================================
  // v2 API — Permission sealed classes
  // ===========================================================================

  @override
  Future<PermissionGrant> check(Permission permission) async {
    final resolved = _resolve(permission);
    final handler = _registry[resolved.runtimeType];

    if (handler == null) {
      // Not registered — doesn't exist on Android.
      return PermissionGrant.notApplicable;
    }

    if (!handler.isSupported(_sdkVersion)) {
      return PermissionGrant.notAvailable;
    }

    if (handler is VersionedHandler) {
      final resolvedHandler = ResolvedVersionedHandler(handler, _sdkVersion);
      return resolvedHandler.check(_api);
    }

    return handler.check(_api);
  }

  @override
  Future<PermissionGrant> request(Permission permission) async {
    final resolved = _resolve(permission);
    final handler = _registry[resolved.runtimeType];

    if (handler == null) {
      return PermissionGrant.notApplicable;
    }

    if (!handler.isSupported(_sdkVersion)) {
      return PermissionGrant.notAvailable;
    }

    if (handler is VersionedHandler) {
      final resolvedHandler = ResolvedVersionedHandler(handler, _sdkVersion);
      return resolvedHandler.request(_api);
    }

    return handler.request(_api);
  }

  @override
  bool isSupported(Permission permission) {
    final resolved = _resolve(permission);
    final handler = _registry[resolved.runtimeType];
    if (handler == null) return false;
    return handler.isSupported(_sdkVersion);
  }

  @override
  Future<bool> openAppSettings() => _api.openAppSettings();

  // ===========================================================================
  // VersionedPermission resolution
  // ===========================================================================

  /// If [permission] is a [VersionedPermission], resolve it to the concrete
  /// [Permission] for the running SDK version. Otherwise return as-is.
  Permission _resolve(Permission permission) {
    if (permission is! VersionedPermission) return permission;

    final sdk = _getSdkVersion();
    for (final variant in permission.variants) {
      if (variant.minApiLevel != null && sdk < variant.minApiLevel!) continue;
      if (variant.maxApiLevel != null && sdk > variant.maxApiLevel!) continue;
      return variant.permission;
    }

    // No variant matches — shouldn't happen for well-defined versioned
    // permissions, but return the original to fail gracefully.
    return permission;
  }
}
