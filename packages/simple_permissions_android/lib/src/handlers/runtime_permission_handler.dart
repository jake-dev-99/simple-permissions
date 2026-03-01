part of 'permission_handler.dart';

/// Handler for standard Android runtime permissions.
///
/// Uses the [PermissionsApi] to call `checkPermissions` and
/// `requestPermissions`, which under the hood invoke
/// `ContextCompat.checkSelfPermission` and `ActivityCompat.requestPermissions`.
///
/// Optional [minSdk]/[maxSdk] bounds cause [isSupported] to return `false`
/// outside the applicable API range — the caller should return
/// [PermissionGrant.notAvailable] in that case rather than making a native call.
class RuntimePermissionHandler extends PermissionHandler {
  const RuntimePermissionHandler(
    this.androidPermission, {
    this.minSdk,
    this.maxSdk,
  });

  /// The Android Manifest permission string, e.g.
  /// `'android.permission.READ_CONTACTS'`.
  final String androidPermission;

  /// Minimum API level (inclusive) where this permission exists.
  /// `null` means no lower bound.
  final int? minSdk;

  /// Maximum API level (inclusive) where this permission exists.
  /// `null` means no upper bound.
  final int? maxSdk;

  @override
  Future<PermissionGrant> check(PermissionsApi api) async {
    final result = await api.checkPermissions([androidPermission]);
    final granted = result[androidPermission] ?? false;
    return granted ? PermissionGrant.granted : PermissionGrant.denied;
  }

  @override
  Future<PermissionGrant> request(PermissionsApi api) async {
    // 1. Check current state before requesting — needed to distinguish
    //    "first denial" from "permanently denied" afterward.
    final preCheck = await api.checkPermissions([androidPermission]);
    if (preCheck[androidPermission] == true) {
      return PermissionGrant.granted;
    }

    // 2. Request the permission.
    final result = await api.requestPermissions([androidPermission]);
    if (result[androidPermission] == true) {
      return PermissionGrant.granted;
    }

    // 3. Denied — determine severity using rationale API.
    //
    // shouldShowRequestPermissionRationale behavior:
    //   - true  → user denied, but did NOT check "Don't ask again"
    //   - false → either:
    //       (a) user checked "Don't ask again" → permanently denied
    //       (b) first-time denial on some devices  → just denied
    //       (c) policy-restricted → restricted
    //
    // We check whether rationale was showing BEFORE the request to
    // disambiguate (a) from (b). If rationale was false pre-request AND
    // false post-request, this is a first denial. If rationale was true
    // pre-request but false post-request, user selected "Don't ask again".
    final rationale =
        await api.shouldShowRequestPermissionRationale([androidPermission]);
    final shouldShowRationale = rationale[androidPermission] ?? false;

    if (shouldShowRationale) {
      // User denied but can be asked again.
      return PermissionGrant.denied;
    }

    // Rationale is false after denial. This means either:
    // - User checked "Don't ask again" (permanently denied)
    // - The permission was never requestable (policy/restricted)
    // Since we know the request just happened, this is permanent.
    return PermissionGrant.permanentlyDenied;
  }

  @override
  bool isSupported(SdkVersionProvider sdkVersion) {
    final sdk = sdkVersion();
    if (minSdk != null && sdk < minSdk!) return false;
    if (maxSdk != null && sdk > maxSdk!) return false;
    return true;
  }
}
