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
    switch (settingType) {
      case SystemSettingType.batteryOptimization:
        final ignoring = await api.isIgnoringBatteryOptimizations();
        return ignoring ? PermissionGrant.granted : PermissionGrant.denied;
      case SystemSettingType.scheduleExactAlarm:
        final canSchedule = await api.canScheduleExactAlarms();
        return canSchedule ? PermissionGrant.granted : PermissionGrant.denied;
      case SystemSettingType.requestInstallPackages:
        final canRequest = await api.canRequestInstallPackages();
        return canRequest ? PermissionGrant.granted : PermissionGrant.denied;
      case SystemSettingType.systemAlertWindow:
        final canDraw = await api.canDrawOverlays();
        return canDraw ? PermissionGrant.granted : PermissionGrant.denied;
      case SystemSettingType.manageExternalStorage:
        final canManage = await api.canManageExternalStorage();
        return canManage ? PermissionGrant.granted : PermissionGrant.denied;
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
      case SystemSettingType.scheduleExactAlarm:
        final canSchedule = await api.canScheduleExactAlarms();
        if (canSchedule) return PermissionGrant.granted;
        final granted = await api.requestScheduleExactAlarms();
        return granted ? PermissionGrant.granted : PermissionGrant.denied;
      case SystemSettingType.requestInstallPackages:
        final canRequest = await api.canRequestInstallPackages();
        if (canRequest) return PermissionGrant.granted;
        final granted = await api.requestInstallPackages();
        return granted ? PermissionGrant.granted : PermissionGrant.denied;
      case SystemSettingType.systemAlertWindow:
        final canDraw = await api.canDrawOverlays();
        if (canDraw) return PermissionGrant.granted;
        final granted = await api.requestDrawOverlays();
        return granted ? PermissionGrant.granted : PermissionGrant.denied;
      case SystemSettingType.manageExternalStorage:
        final canManage = await api.canManageExternalStorage();
        if (canManage) return PermissionGrant.granted;
        final granted = await api.requestManageExternalStorage();
        return granted ? PermissionGrant.granted : PermissionGrant.denied;
    }
  }

  @override
  bool isSupported(SdkVersionProvider sdkVersion) {
    final sdk = sdkVersion();
    switch (settingType) {
      case SystemSettingType.batteryOptimization:
        return sdk >= 23;
      case SystemSettingType.scheduleExactAlarm:
        return sdk >= 31;
      case SystemSettingType.requestInstallPackages:
        return sdk >= 26;
      case SystemSettingType.systemAlertWindow:
        return sdk >= 23;
      case SystemSettingType.manageExternalStorage:
        return sdk >= 30;
    }
  }
}

/// The kinds of system settings that [SystemSettingHandler] can manage.
enum SystemSettingType {
  /// Battery optimization exemption via
  /// `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
  batteryOptimization,

  /// Exact alarm scheduling via `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`.
  scheduleExactAlarm,

  /// Install packages from unknown sources via
  /// `ACTION_MANAGE_UNKNOWN_APP_SOURCES`.
  requestInstallPackages,

  /// Draw overlays on top of other apps via `ACTION_MANAGE_OVERLAY_PERMISSION`.
  systemAlertWindow,

  /// Manage all files access via
  /// `ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`.
  manageExternalStorage,
}
