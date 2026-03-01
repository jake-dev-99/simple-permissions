part of 'permission.dart';

/// Permissions related to camera access.
sealed class CameraPermission extends Permission {
  const CameraPermission();
}

/// Access the device camera for photo/video capture.
///
/// - **Android**: `android.permission.CAMERA`
/// - **iOS**: `NSCameraUsageDescription` / `AVCaptureDevice`
/// - **macOS**: `AVCaptureDevice` (System Preferences prompt)
class CameraAccess extends CameraPermission {
  const CameraAccess();

  @override
  String get identifier => 'camera_access';
}
