part of 'permission.dart';

/// Permissions related to health data access.
///
/// This capability intentionally models health access as one logical grant.
/// The previous read/write split implied a precision the platform adapters did
/// not implement truthfully.
///
/// - **Android**: Not currently supported by this plugin
/// - **iOS**: HealthKit (`HKHealthStore`)
sealed class HealthPermission extends Permission {
  const HealthPermission();
}

/// Access health data.
class HealthAccess extends HealthPermission {
  const HealthAccess();

  @override
  String get identifier => 'health_access';
}
