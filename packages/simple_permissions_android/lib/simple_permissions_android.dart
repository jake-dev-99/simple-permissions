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

  final Map<Type, PermissionHandler> _registry =
      buildAndroidPermissionRegistry();

  // Caches the SDK version obtained from the native side.
  int? _cachedSdkVersion;
  Future<int>? _sdkVersionFuture;

  @override
  Future<void> initialize() async {
    await _ensureSdkVersionLoaded();
  }

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

  Future<bool> _hasForegroundLocationGrant() async {
    final foreground = await _api.checkPermissions([
      AndroidPermission.fineLocation,
      AndroidPermission.coarseLocation,
    ]);
    return foreground[AndroidPermission.fineLocation] == true ||
        foreground[AndroidPermission.coarseLocation] == true;
  }

  // ===========================================================================
  // v2 API — Permission sealed classes
  // ===========================================================================

  @override
  Future<PermissionGrant> check(Permission permission) async {
    final sdk = await _ensureSdkVersionLoaded();
    final resolved = _resolve(permission, sdk);
    if (resolved == null) return PermissionGrant.notAvailable;
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
    if (resolved == null) return PermissionGrant.notAvailable;
    final handler = _registry[resolved.runtimeType];

    if (handler == null) {
      return PermissionGrant.notApplicable;
    }

    if (!handler.isSupported(() => sdk)) {
      return PermissionGrant.notAvailable;
    }

    if (sdk >= 30 && resolved is BackgroundLocation) {
      final hasForegroundGrant = await _hasForegroundLocationGrant();
      if (!hasForegroundGrant) {
        return PermissionGrant.denied;
      }
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
      if (resolved == null) {
        resolvedGrants[permission] = PermissionGrant.notAvailable;
        continue;
      }
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
      if (resolved == null) {
        resolvedGrants[permission] = PermissionGrant.notAvailable;
        continue;
      }
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
      final preRequestRationale =
          await _api.shouldShowRequestPermissionRationale(runtimePermissions);
      final permissionsToRequest = runtimePermissions
          .where((permission) => preCheck[permission] != true)
          .toSet();

      if (sdk >= 30 &&
          permissionsToRequest.contains(AndroidPermission.backgroundLocation)) {
        final hasForegroundGrant = await _hasForegroundLocationGrant();
        if (!hasForegroundGrant) {
          permissionsToRequest.remove(AndroidPermission.backgroundLocation);
          for (final entry in runtimeByOriginal.entries) {
            if (entry.value == AndroidPermission.backgroundLocation) {
              resolvedGrants[entry.key] = PermissionGrant.denied;
            }
          }
        }
      }

      Map<String, bool> requestResults = const {};
      if (permissionsToRequest.isNotEmpty) {
        requestResults = await _api.requestPermissions(
          permissionsToRequest.toList(),
        );
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
        if (resolvedGrants.containsKey(entry.key)) {
          continue;
        }
        final permission = entry.value;
        if (preCheck[permission] == true ||
            requestResults[permission] == true) {
          resolvedGrants[entry.key] = PermissionGrant.granted;
          continue;
        }
        resolvedGrants[entry.key] = classifyRuntimeDenial(
          wasGrantedBeforeRequest: preCheck[permission] == true,
          isGrantedAfterRequest: requestResults[permission] == true,
          showedRationaleBeforeRequest:
              preRequestRationale[permission] ?? false,
          shouldShowRationaleAfterRequest:
              rationaleResults[permission] ?? false,
        );
      }
    }

    return PermissionResult({
      for (final permission in permissions)
        permission: resolvedGrants[permission] ?? PermissionGrant.notApplicable,
    });
  }

  @override
  Future<bool> isSupported(Permission permission) async {
    final sdk = await _ensureSdkVersionLoaded();
    final resolved = _resolve(permission, sdk);
    if (resolved == null) return false;
    final handler = _registry[resolved.runtimeType];
    if (handler == null) return false;
    return handler.isSupported(() => sdk);
  }

  @override
  Future<bool> openAppSettings() => _api.openAppSettings();

  @override
  Future<LocationAccuracyStatus> checkLocationAccuracy() async {
    final checks = await _api.checkPermissions([
      AndroidPermission.fineLocation,
      AndroidPermission.coarseLocation,
    ]);
    if (checks[AndroidPermission.fineLocation] == true) {
      return LocationAccuracyStatus.precise;
    }
    if (checks[AndroidPermission.coarseLocation] == true) {
      return LocationAccuracyStatus.reduced;
    }
    return LocationAccuracyStatus.none;
  }

  // ===========================================================================
  // VersionedPermission resolution
  // ===========================================================================

  /// Resolves [permission] to the concrete [Permission] for the running
  /// SDK. Returns the input unchanged for non-[VersionedPermission]s, and
  /// `null` when the caller supplied a [VersionedPermission] whose variants
  /// don't cover [sdk]. Callers treat `null` as [PermissionGrant.notAvailable]
  /// rather than silently falling through to a registry miss.
  Permission? _resolve(Permission permission, int sdk) {
    if (permission is! VersionedPermission) return permission;

    for (final variant in permission.variants) {
      final min = variant.minApiLevel;
      final max = variant.maxApiLevel;
      if (min != null && sdk < min) continue;
      if (max != null && sdk > max) continue;
      return variant.permission;
    }
    return null;
  }
}
