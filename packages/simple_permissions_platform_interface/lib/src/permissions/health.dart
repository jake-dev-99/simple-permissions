part of 'permission.dart';

/// Permissions related to health data access.
///
/// - **Android**: Health Connect API (`android.permission.health.*`)
/// - **iOS**: HealthKit (`HKHealthStore`)
sealed class HealthPermission extends Permission {
  const HealthPermission();
}

/// Read health data.
///
/// - **Android**: Health Connect read permissions (API 34+ integrated)
/// - **iOS**: `HKHealthStore.authorizationStatus` for read
class ReadHealth extends HealthPermission {
  const ReadHealth();

  @override
  String get identifier => 'read_health';
}

/// Write health data.
///
/// - **Android**: Health Connect write permissions (API 34+ integrated)
/// - **iOS**: `HKHealthStore.authorizationStatus` for write/share
class WriteHealth extends HealthPermission {
  const WriteHealth();

  @override
  String get identifier => 'write_health';
}
