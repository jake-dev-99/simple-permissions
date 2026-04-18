part of 'permission_handler.dart';

/// Handler for system-level permissions that require settings intents
/// rather than standard runtime permission prompts.
///
/// Supported flows:
/// - Battery optimization exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`)
/// - Exact alarms (`ACTION_REQUEST_SCHEDULE_EXACT_ALARM`)
/// - Overlay permission (`ACTION_MANAGE_OVERLAY_PERMISSION`)
/// - Install packages from unknown sources (`ACTION_MANAGE_UNKNOWN_APP_SOURCES`)
/// - All files access (`ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`)
class SystemSettingHandler extends PermissionHandler {
  const SystemSettingHandler(this.settingType);

  /// What kind of system setting this handler manages.
  final SystemSettingType settingType;

  @override
  Future<PermissionGrant> check(PermissionsApi api) async {
    final granted = await settingType._checkFn(api);
    return granted ? PermissionGrant.granted : PermissionGrant.denied;
  }

  @override
  Future<PermissionGrant> request(PermissionsApi api) async {
    if (await settingType._checkFn(api)) return PermissionGrant.granted;
    final granted = await settingType._requestFn(api);
    return granted ? PermissionGrant.granted : PermissionGrant.denied;
  }

  @override
  bool isSupported(SdkVersionProvider sdkVersion) =>
      sdkVersion() >= settingType._minSdk;
}

/// The kinds of system settings that [SystemSettingHandler] can manage.
enum SystemSettingType {
  /// Battery optimization exemption via
  /// `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
  batteryOptimization(23),

  /// Exact alarm scheduling via `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`.
  scheduleExactAlarm(31),

  /// Install packages from unknown sources via
  /// `ACTION_MANAGE_UNKNOWN_APP_SOURCES`.
  requestInstallPackages(26),

  /// Draw overlays on top of other apps via `ACTION_MANAGE_OVERLAY_PERMISSION`.
  systemAlertWindow(23),

  /// Manage all files access via
  /// `ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`.
  manageExternalStorage(30);

  const SystemSettingType(this._minSdk);

  /// Minimum Android SDK level where this setting is applicable.
  final int _minSdk;

  /// Returns the check function for this setting type.
  Future<bool> Function(PermissionsApi) get _checkFn => switch (this) {
        batteryOptimization => (api) => api.isIgnoringBatteryOptimizations(),
        scheduleExactAlarm => (api) => api.canScheduleExactAlarms(),
        requestInstallPackages => (api) => api.canRequestInstallPackages(),
        systemAlertWindow => (api) => api.canDrawOverlays(),
        manageExternalStorage => (api) => api.canManageExternalStorage(),
      };

  /// Returns the request function for this setting type.
  Future<bool> Function(PermissionsApi) get _requestFn => switch (this) {
        batteryOptimization => (api) => api.requestIgnoreBatteryOptimizations(),
        scheduleExactAlarm => (api) => api.requestScheduleExactAlarms(),
        requestInstallPackages => (api) => api.requestInstallPackages(),
        systemAlertWindow => (api) => api.requestDrawOverlays(),
        manageExternalStorage => (api) => api.requestManageExternalStorage(),
      };
}
