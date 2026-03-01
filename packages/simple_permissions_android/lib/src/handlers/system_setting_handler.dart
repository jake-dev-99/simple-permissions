part of 'permission_handler.dart';

/// Handler for system-level permissions that require settings intents
/// rather than standard runtime permission prompts.
///
/// Currently supports:
/// - Battery optimization exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`)
///
/// Additional system settings (overlay, exact alarm, install packages) can
/// be added by extending this class or adding mode parameters.
class SystemSettingHandler extends PermissionHandler {
  const SystemSettingHandler(this.settingType);

  /// What kind of system setting this handler manages.
  final SystemSettingType settingType;

  @override
  Future<PermissionGrant> check(PermissionsApi api) async {
    switch (settingType) {
      case SystemSettingType.batteryOptimization:
        final ignoring = await api.isIgnoringBatteryOptimizations();
        return ignoring ? PermissionGrant.granted : PermissionGrant.denied;
    }
  }

  @override
  Future<PermissionGrant> request(PermissionsApi api) async {
    switch (settingType) {
      case SystemSettingType.batteryOptimization:
        final ignoring = await api.isIgnoringBatteryOptimizations();
        if (ignoring) return PermissionGrant.granted;
        final granted = await api.requestIgnoreBatteryOptimizations();
        return granted ? PermissionGrant.granted : PermissionGrant.denied;
    }
  }

  @override
  bool isSupported(SdkVersionProvider sdkVersion) => true;
}

/// The kinds of system settings that [SystemSettingHandler] can manage.
enum SystemSettingType {
  /// Battery optimization exemption via
  /// `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
  batteryOptimization,
}
