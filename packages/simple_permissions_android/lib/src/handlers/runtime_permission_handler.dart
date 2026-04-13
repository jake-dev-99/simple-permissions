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
    final preCheck = await api.checkPermissions([androidPermission]);
    final wasGrantedBeforeRequest = preCheck[androidPermission] == true;
    if (wasGrantedBeforeRequest) {
      return PermissionGrant.granted;
    }

    final preRequestRationale =
        await api.shouldShowRequestPermissionRationale([androidPermission]);
    final showedRationaleBeforeRequest =
        preRequestRationale[androidPermission] ?? false;

    final result = await api.requestPermissions([androidPermission]);
    final rationale =
        await api.shouldShowRequestPermissionRationale([androidPermission]);
    return classifyRuntimeDenial(
      wasGrantedBeforeRequest: wasGrantedBeforeRequest,
      isGrantedAfterRequest: result[androidPermission] == true,
      showedRationaleBeforeRequest: showedRationaleBeforeRequest,
      shouldShowRationaleAfterRequest: rationale[androidPermission] ?? false,
    );
  }

  @override
  bool isSupported(SdkVersionProvider sdkVersion) {
    final sdk = sdkVersion();
    if (minSdk != null && sdk < minSdk!) return false;
    if (maxSdk != null && sdk > maxSdk!) return false;
    return true;
  }
}
