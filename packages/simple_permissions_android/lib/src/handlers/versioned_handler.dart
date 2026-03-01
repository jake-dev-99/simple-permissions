part of 'permission_handler.dart';

/// Handler that delegates to version-specific inner handlers based on SDK level.
///
/// When Android introduces a permission split (e.g. `READ_EXTERNAL_STORAGE`
/// replaced by `READ_MEDIA_IMAGES` at API 33), the caller uses a single
/// [VersionedHandler] that automatically picks the right inner handler.
///
/// Inner handlers are evaluated in order — the first whose SDK range matches
/// the running device is used. This means handlers should be ordered from
/// **newest to oldest** API level.
///
/// ```dart
/// VersionedHandler([
///   VersionedHandlerEntry(minSdk: 33, handler: RuntimePermissionHandler('READ_MEDIA_IMAGES')),
///   VersionedHandlerEntry(maxSdk: 32, handler: RuntimePermissionHandler('READ_EXTERNAL_STORAGE')),
/// ])
/// ```
class VersionedHandler extends PermissionHandler {
  const VersionedHandler(this.entries);

  /// Ordered list of version-specific handlers (newest API first).
  final List<VersionedHandlerEntry> entries;

  /// Resolve the active handler for the current SDK version.
  ///
  /// Returns `null` if no entry matches (should not happen for well-configured
  /// registrations — every SDK version in `[minSdk..maxSdk]` range should be
  /// covered).
  PermissionHandler? _resolve(SdkVersionProvider sdkVersion) {
    final sdk = sdkVersion();
    for (final entry in entries) {
      if (entry.minSdk != null && sdk < entry.minSdk!) continue;
      if (entry.maxSdk != null && sdk > entry.maxSdk!) continue;
      return entry.handler;
    }
    return null;
  }

  @override
  Future<PermissionGrant> check(PermissionsApi api) async {
    throw UnsupportedError(
      'VersionedHandler.check() must be called through ResolvedVersionedHandler',
    );
  }

  @override
  Future<PermissionGrant> request(PermissionsApi api) async {
    throw UnsupportedError(
      'VersionedHandler.request() must be called through ResolvedVersionedHandler',
    );
  }

  @override
  bool isSupported(SdkVersionProvider sdkVersion) {
    return _resolve(sdkVersion) != null;
  }
}

/// A versioned handler that has been bound to a specific SDK version.
///
/// Created by the registry when resolving a [VersionedHandler] — the
/// SDK version is injected so that [check] and [request] can delegate
/// to the correct inner handler.
class ResolvedVersionedHandler extends PermissionHandler {
  const ResolvedVersionedHandler(this._inner, this._sdkVersion);

  final VersionedHandler _inner;
  final SdkVersionProvider _sdkVersion;

  @override
  Future<PermissionGrant> check(PermissionsApi api) async {
    final handler = _inner._resolve(_sdkVersion);
    if (handler == null) return PermissionGrant.notAvailable;
    return handler.check(api);
  }

  @override
  Future<PermissionGrant> request(PermissionsApi api) async {
    final handler = _inner._resolve(_sdkVersion);
    if (handler == null) return PermissionGrant.notAvailable;
    return handler.request(api);
  }

  @override
  bool isSupported(SdkVersionProvider sdkVersion) {
    return _inner.isSupported(sdkVersion);
  }
}

/// One entry in a [VersionedHandler]'s list of version-specific handlers.
class VersionedHandlerEntry {
  const VersionedHandlerEntry({
    required this.handler,
    this.minSdk,
    this.maxSdk,
  });

  /// The handler to use when the SDK version is in range.
  final PermissionHandler handler;

  /// Minimum API level (inclusive). `null` = no lower bound.
  final int? minSdk;

  /// Maximum API level (inclusive). `null` = no upper bound.
  final int? maxSdk;
}
