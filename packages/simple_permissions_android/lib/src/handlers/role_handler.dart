part of 'permission_handler.dart';

/// Handler for Android app-role requests via [RoleManager].
///
/// Roles are conceptually different from runtime permissions — the user is
/// asked to designate this app as the default handler for a category (SMS,
/// dialer, browser, etc.). The check/request cycle uses `isRoleHeld` /
/// `requestRole` through the Pigeon bridge.
class RoleHandler extends PermissionHandler {
  const RoleHandler(this.roleId);

  /// The Android role string, e.g. `'android.app.role.SMS'`.
  final String roleId;

  @override
  Future<PermissionGrant> check(PermissionsApi api) async {
    final held = await api.isRoleHeld(roleId);
    return held ? PermissionGrant.granted : PermissionGrant.denied;
  }

  @override
  Future<PermissionGrant> request(PermissionsApi api) async {
    final held = await api.isRoleHeld(roleId);
    if (held) return PermissionGrant.granted;

    final granted = await api.requestRole(roleId);
    return granted ? PermissionGrant.granted : PermissionGrant.denied;
  }

  /// Roles are available on all supported API levels (minSdk 30 ≥ API 29
  /// where RoleManager was introduced).
  @override
  bool isSupported(SdkVersionProvider sdkVersion) => true;
}
