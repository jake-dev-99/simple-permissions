part of 'permission.dart';

/// Permissions related to Bluetooth access.
///
/// Android's Bluetooth permission model changed at API 31:
/// - API < 31: `BLUETOOTH` + `BLUETOOTH_ADMIN`
/// - API 31+: `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`
///
/// Use [VersionedPermission.bluetooth()] for automatic resolution.
sealed class BluetoothPermission extends Permission {
  const BluetoothPermission();
}

/// Connect to paired Bluetooth devices.
///
/// - **Android**: `android.permission.BLUETOOTH_CONNECT` (API 31+)
/// - **iOS**: `CBManager` authorization (`NSBluetoothAlwaysUsageDescription`)
class BluetoothConnect extends BluetoothPermission {
  const BluetoothConnect();

  @override
  String get identifier => 'bluetooth_connect';
}

/// Scan for nearby Bluetooth devices.
///
/// - **Android**: `android.permission.BLUETOOTH_SCAN` (API 31+)
/// - **iOS**: Included in Bluetooth usage authorization
class BluetoothScan extends BluetoothPermission {
  const BluetoothScan();

  @override
  String get identifier => 'bluetooth_scan';
}

/// Make the device discoverable to other Bluetooth devices.
///
/// - **Android**: `android.permission.BLUETOOTH_ADVERTISE` (API 31+)
/// - **iOS**: Included in Bluetooth usage authorization
class BluetoothAdvertise extends BluetoothPermission {
  const BluetoothAdvertise();

  @override
  String get identifier => 'bluetooth_advertise';
}

/// Legacy Bluetooth permission (pre-API 31).
///
/// - **Android**: `android.permission.BLUETOOTH` (API < 31)
/// - **iOS**: Not applicable (use [BluetoothConnect])
///
/// Superseded by [BluetoothConnect], [BluetoothScan], [BluetoothAdvertise].
class BluetoothLegacy extends BluetoothPermission {
  const BluetoothLegacy();

  @override
  String get identifier => 'bluetooth_legacy';
}

/// Legacy Bluetooth admin permission (pre-API 31).
///
/// - **Android**: `android.permission.BLUETOOTH_ADMIN` (API < 31)
/// - **iOS**: Not applicable
///
/// Superseded by [BluetoothScan], [BluetoothAdvertise].
class BluetoothAdminLegacy extends BluetoothPermission {
  const BluetoothAdminLegacy();

  @override
  String get identifier => 'bluetooth_admin_legacy';
}
