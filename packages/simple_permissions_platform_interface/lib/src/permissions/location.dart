part of 'permission.dart';

/// Permissions related to device location access.
sealed class LocationPermission extends Permission {
  const LocationPermission();
}

/// Approximate (network-based) location.
///
/// - **Android**: `android.permission.ACCESS_COARSE_LOCATION`
/// - **iOS**: Included in "When In Use" authorization
class CoarseLocation extends LocationPermission {
  const CoarseLocation();

  @override
  String get identifier => 'coarse_location';
}

/// Precise (GPS) location.
///
/// - **Android**: `android.permission.ACCESS_FINE_LOCATION`
/// - **iOS**: `CLLocationManager` "When In Use" with accuracy
class FineLocation extends LocationPermission {
  const FineLocation();

  @override
  String get identifier => 'fine_location';
}

/// Location access while the app is backgrounded.
///
/// - **Android**: `android.permission.ACCESS_BACKGROUND_LOCATION` (API 29+)
/// - **iOS**: `CLLocationManager` "Always" authorization
///
/// On Android 30+, this should be requested in a separate second step
/// **after** [FineLocation] or [CoarseLocation] is granted.
class BackgroundLocation extends LocationPermission {
  const BackgroundLocation();

  @override
  String get identifier => 'background_location';
}
