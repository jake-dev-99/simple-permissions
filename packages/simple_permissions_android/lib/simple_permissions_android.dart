library;

import 'dart:async';

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

  // Caches the SDK version obtained from the native side.
  int? _cachedSdkVersion;
  Future<int>? _sdkVersionFuture;

  Future<int> _ensureSdkVersionLoaded() async {
    if (_sdkVersionOverride != null) {
      final sdk = _sdkVersionOverride();
      _cachedSdkVersion = sdk;
      return sdk;
    }
    final cached = _cachedSdkVersion;
    if (cached != null) return cached;

    final inFlight = _sdkVersionFuture;
    if (inFlight != null) return inFlight;

    final future = _api.getSdkVersion().then((sdk) {
      _cachedSdkVersion = sdk;
      return sdk;
    });
    _sdkVersionFuture = future;
    return future.whenComplete(() {
      if (identical(_sdkVersionFuture, future)) {
        _sdkVersionFuture = null;
      }
    });
  }

  void _maybeFetchSdkVersion() {
    if (_sdkVersionOverride != null ||
        _cachedSdkVersion != null ||
        _sdkVersionFuture != null) {
      return;
    }
    unawaited(_ensureSdkVersionLoaded());
  }

  bool _isSupportedWithUnknownSdk(PermissionHandler handler) {
    // isSupported is synchronous, so if SDK is not loaded yet we use a
    // conservative answer: only permissions without SDK constraints are
    // considered supported until the async SDK lookup completes.
    if (handler is RuntimePermissionHandler) {
      return handler.minSdk == null && handler.maxSdk == null;
    }
    if (handler is SystemSettingHandler) return false;
    return true;
  }

  bool _isHandlerSupportedSync(PermissionHandler handler) {
    final override = _sdkVersionOverride;
    if (override != null) {
      return handler.isSupported(override);
    }
    final sdk = _cachedSdkVersion;
    if (sdk != null) {
      return handler.isSupported(() => sdk);
    }
    _maybeFetchSdkVersion();
    return _isSupportedWithUnknownSdk(handler);
  }

  // ===========================================================================
  // v2 API — Permission sealed classes
  // ===========================================================================

  @override
  Future<PermissionGrant> check(Permission permission) async {
    final sdk = await _ensureSdkVersionLoaded();
    final resolved = _resolve(permission, sdk);
    final handler = _registry[resolved.runtimeType];

    if (handler == null) {
      // Not registered — doesn't exist on Android.
      return PermissionGrant.notApplicable;
    }

    if (!handler.isSupported(() => sdk)) {
      return PermissionGrant.notAvailable;
    }

    return handler.check(_api);
  }

  @override
  Future<PermissionGrant> request(Permission permission) async {
    final sdk = await _ensureSdkVersionLoaded();
    final resolved = _resolve(permission, sdk);
    final handler = _registry[resolved.runtimeType];

    if (handler == null) {
      return PermissionGrant.notApplicable;
    }

    if (!handler.isSupported(() => sdk)) {
      return PermissionGrant.notAvailable;
    }

    return handler.request(_api);
  }

  @override
  Future<PermissionResult> checkAll(List<Permission> permissions) async {
    final sdk = await _ensureSdkVersionLoaded();
    final runtimeByOriginal = <Permission, String>{};
    final resolvedGrants = <Permission, PermissionGrant>{};

    for (final permission in permissions) {
      final resolved = _resolve(permission, sdk);
      final handler = _registry[resolved.runtimeType];
      if (handler == null) {
        resolvedGrants[permission] = PermissionGrant.notApplicable;
        continue;
      }
      if (!handler.isSupported(() => sdk)) {
        resolvedGrants[permission] = PermissionGrant.notAvailable;
        continue;
      }
      if (handler is RuntimePermissionHandler) {
        runtimeByOriginal[permission] = handler.androidPermission;
        continue;
      }
      resolvedGrants[permission] = await handler.check(_api);
    }

    if (runtimeByOriginal.isNotEmpty) {
      final runtimePermissions = runtimeByOriginal.values.toSet().toList();
      final checkResults = await _api.checkPermissions(runtimePermissions);
      for (final entry in runtimeByOriginal.entries) {
        final granted = checkResults[entry.value] ?? false;
        resolvedGrants[entry.key] =
            granted ? PermissionGrant.granted : PermissionGrant.denied;
      }
    }

    return PermissionResult({
      for (final permission in permissions)
        permission: resolvedGrants[permission] ?? PermissionGrant.notApplicable,
    });
  }

  /// Requests multiple permissions, batching runtime permissions into a single
  /// native round-trip for efficiency.
  ///
  /// Compared with single-permission [request], runtime permissions in this
  /// batch path classify denied grants using one post-denial rationale pass
  /// over denied items rather than per-item request flow.
  @override
  Future<PermissionResult> requestAll(List<Permission> permissions) async {
    final sdk = await _ensureSdkVersionLoaded();
    final runtimeByOriginal = <Permission, String>{};
    final resolvedGrants = <Permission, PermissionGrant>{};

    for (final permission in permissions) {
      final resolved = _resolve(permission, sdk);
      final handler = _registry[resolved.runtimeType];
      if (handler == null) {
        resolvedGrants[permission] = PermissionGrant.notApplicable;
        continue;
      }
      if (!handler.isSupported(() => sdk)) {
        resolvedGrants[permission] = PermissionGrant.notAvailable;
        continue;
      }
      if (handler is RuntimePermissionHandler) {
        runtimeByOriginal[permission] = handler.androidPermission;
        continue;
      }
      resolvedGrants[permission] = await handler.request(_api);
    }

    if (runtimeByOriginal.isNotEmpty) {
      final runtimePermissions = runtimeByOriginal.values.toSet().toList();
      final preCheck = await _api.checkPermissions(runtimePermissions);
      final permissionsToRequest = runtimePermissions
          .where((permission) => preCheck[permission] != true)
          .toList();

      Map<String, bool> requestResults = const {};
      if (permissionsToRequest.isNotEmpty) {
        requestResults = await _api.requestPermissions(permissionsToRequest);
      }

      final deniedPermissions = <String>{
        for (final permission in permissionsToRequest)
          if (requestResults[permission] != true) permission,
      };
      Map<String, bool> rationaleResults = const {};
      if (deniedPermissions.isNotEmpty) {
        rationaleResults = await _api.shouldShowRequestPermissionRationale(
          deniedPermissions.toList(),
        );
      }

      for (final entry in runtimeByOriginal.entries) {
        final permission = entry.value;
        if (preCheck[permission] == true ||
            requestResults[permission] == true) {
          resolvedGrants[entry.key] = PermissionGrant.granted;
          continue;
        }
        final shouldShowRationale = rationaleResults[permission] ?? false;
        resolvedGrants[entry.key] = shouldShowRationale
            ? PermissionGrant.denied
            : PermissionGrant.permanentlyDenied;
      }
    }

    return PermissionResult({
      for (final permission in permissions)
        permission: resolvedGrants[permission] ?? PermissionGrant.notApplicable,
    });
  }

  @override
  bool isSupported(Permission permission) {
    if (permission is VersionedPermission &&
        _sdkVersionOverride == null &&
        _cachedSdkVersion == null) {
      _maybeFetchSdkVersion();
      return permission.variants.any((variant) {
        final handler = _registry[variant.permission.runtimeType];
        if (handler == null) return false;
        return _isSupportedWithUnknownSdk(handler);
      });
    }

    final sdk = _sdkVersionOverride?.call() ?? _cachedSdkVersion;
    final resolved = _resolve(permission, sdk);
    final handler = _registry[resolved.runtimeType];
    if (handler == null) return false;
    return _isHandlerSupportedSync(handler);
  }

  @override
  Future<bool> openAppSettings() => _api.openAppSettings();

  // ===========================================================================
  // VersionedPermission resolution
  // ===========================================================================

  /// If [permission] is a [VersionedPermission], resolve it to the concrete
  /// [Permission] for the running SDK version. Otherwise return as-is.
  Permission _resolve(Permission permission, [int? sdk]) {
    if (permission is! VersionedPermission) return permission;

    final effectiveSdk =
        sdk ?? _sdkVersionOverride?.call() ?? _cachedSdkVersion;
    if (effectiveSdk == null) return permission;

    for (final variant in permission.variants) {
      if (variant.minApiLevel != null && effectiveSdk < variant.minApiLevel!) {
        continue;
      }
      if (variant.maxApiLevel != null && effectiveSdk > variant.maxApiLevel!) {
        continue;
      }
      return variant.permission;
    }

    // No variant matches — shouldn't happen for well-defined versioned
    // permissions, but return the original to fail gracefully.
    return permission;
  }
}
