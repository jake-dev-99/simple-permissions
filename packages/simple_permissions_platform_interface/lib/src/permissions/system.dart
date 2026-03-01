part of 'permission.dart';

/// System-level permissions that typically require special flows
/// (settings intents, system dialogs) rather than standard runtime prompts.
sealed class SystemPermission extends Permission {
  const SystemPermission();
}

/// Exemption from battery optimization (doze mode).
///
/// - **Android**: `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (Settings intent)
/// - **iOS**: Not applicable (no equivalent concept)
class BatteryOptimizationExemption extends SystemPermission {
  const BatteryOptimizationExemption();

  @override
  String get identifier => 'battery_optimization_exemption';
}

/// Schedule exact alarms.
///
/// - **Android**: `android.permission.SCHEDULE_EXACT_ALARM` (API 31+)
///   or `USE_EXACT_ALARM` (API 33+, auto-granted for specific categories)
/// - **iOS**: Not applicable (local notifications handle scheduling)
class ScheduleExactAlarm extends SystemPermission {
  const ScheduleExactAlarm();

  @override
  String get identifier => 'schedule_exact_alarm';
}

/// Install packages from unknown sources.
///
/// - **Android**: `android.permission.REQUEST_INSTALL_PACKAGES` (API 26+)
/// - **iOS**: Not applicable
class RequestInstallPackages extends SystemPermission {
  const RequestInstallPackages();

  @override
  String get identifier => 'request_install_packages';
}

/// Draw overlays on top of other apps.
///
/// - **Android**: `android.permission.SYSTEM_ALERT_WINDOW`
///   (requires `Settings.canDrawOverlays()` check + settings intent)
/// - **iOS**: Not applicable
class SystemAlertWindow extends SystemPermission {
  const SystemAlertWindow();

  @override
  String get identifier => 'system_alert_window';
}
