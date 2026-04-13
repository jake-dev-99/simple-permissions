/// Abstract contract for the native iOS permissions bridge.
///
/// This interface decouples the Dart plugin logic from the Pigeon-generated
/// [PermissionsIosHostApi] concrete class, allowing unit testing with a
/// simple in-memory fake.
abstract interface class PermissionsIosApi {
  /// Check the current authorization status for a permission.
  ///
  /// Returns a wire string: "granted", "denied", "permanentlyDenied",
  /// "restricted", "limited", "notApplicable", "notAvailable", "provisional".
  Future<String> checkPermission(String identifier);

  /// Request authorization for a permission.
  ///
  /// Returns a wire string with the same values as [checkPermission].
  Future<String> requestPermission(String identifier);

  /// Whether the permission identifier is supported on the running device/OS.
  Future<bool> isSupported(String identifier);

  /// Open this app's settings page in the Settings app.
  Future<bool> openAppSettings();

  /// Check current location accuracy level on iOS.
  Future<String> checkLocationAccuracy();
}
