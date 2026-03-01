part of 'permission.dart';

/// Permissions related to device sensors and activity recognition.
sealed class SensorPermission extends Permission {
  const SensorPermission();
}

/// Access body sensors (e.g., heart rate monitor).
///
/// - **Android**: `android.permission.BODY_SENSORS`
/// - **iOS**: `CMMotionActivityManager` (partially overlapping)
class BodySensors extends SensorPermission {
  const BodySensors();

  @override
  String get identifier => 'body_sensors';
}

/// Recognize physical activity (walking, driving, etc.).
///
/// - **Android**: `android.permission.ACTIVITY_RECOGNITION` (API 29+)
/// - **iOS**: `CMMotionActivityManager.authorizationStatus()`
class ActivityRecognition extends SensorPermission {
  const ActivityRecognition();

  @override
  String get identifier => 'activity_recognition';
}

/// Background body-sensor access.
///
/// - **Android**: `android.permission.BODY_SENSORS_BACKGROUND` (API 33+)
/// - **iOS**: Not applicable
class BodySensorsBackground extends SensorPermission {
  const BodySensorsBackground();

  @override
  String get identifier => 'body_sensors_background';
}

/// Ultra-wideband ranging access.
///
/// - **Android**: `android.permission.UWB_RANGING` (API 31+)
/// - **iOS**: Not applicable in this plugin
class UwbRanging extends SensorPermission {
  const UwbRanging();

  @override
  String get identifier => 'uwb_ranging';
}
