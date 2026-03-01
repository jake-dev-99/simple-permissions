part of 'permission.dart';

/// Permissions related to Wi-Fi and nearby device discovery.
sealed class WifiPermission extends Permission {
  const WifiPermission();
}

/// Discover nearby Wi-Fi devices (Wi-Fi Aware, Wi-Fi Direct).
///
/// - **Android**: `android.permission.NEARBY_WIFI_DEVICES` (API 33+)
/// - **iOS**: Not applicable (peer-to-peer uses Multipeer Connectivity)
class NearbyWifiDevices extends WifiPermission {
  const NearbyWifiDevices();

  @override
  String get identifier => 'nearby_wifi_devices';
}
