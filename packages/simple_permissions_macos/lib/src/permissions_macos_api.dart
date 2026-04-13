/// Abstract contract for the native macOS permissions bridge.
///
/// This interface decouples the Dart plugin logic from the Pigeon-generated
/// [PermissionsMacosHostApi] concrete class, allowing unit testing with a
/// simple in-memory fake.
abstract interface class PermissionsMacosApi {
  /// Check the current authorization status for a permission.
  ///
  /// Returns a wire string: "granted", "denied", "permanentlyDenied",
  /// "restricted", "limited", "notApplicable", "notAvailable", "provisional".
  Future<String> checkPermission(String identifier);

  /// Request authorization for a permission.
  ///
  /// Returns a wire string with the same values as [checkPermission].
  Future<String> requestPermission(String identifier);

  /// Whether the permission identifier is supported on the running macOS host.
  Future<bool> isSupported(String identifier);

  /// Open this app's settings in System Settings / System Preferences.
  Future<bool> openAppSettings();

  /// Check current location accuracy level on macOS.
  Future<String> checkLocationAccuracy();
}
