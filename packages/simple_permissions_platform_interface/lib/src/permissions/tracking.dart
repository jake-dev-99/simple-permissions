part of 'permission.dart';

/// Permissions related to app tracking transparency.
///
/// This is primarily an iOS concept (App Tracking Transparency framework).
/// Other platforms return [PermissionGrant.notApplicable].
sealed class TrackingPermission extends Permission {
  const TrackingPermission();
}

/// Request user authorization to track across apps and websites.
///
/// - **Android**: Not applicable
/// - **iOS**: `ATTrackingManager.trackingAuthorizationStatus` (iOS 14+)
class AppTrackingTransparency extends TrackingPermission {
  const AppTrackingTransparency();

  @override
  String get identifier => 'app_tracking_transparency';
}
