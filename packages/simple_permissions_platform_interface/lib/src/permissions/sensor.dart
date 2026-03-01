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
