/// Abstract contract for the native Android permissions bridge.
///
/// This interface decouples handler logic from the Pigeon-generated
/// [PermissionsHostApi] concrete class, making handlers testable
/// without platform channels.
///
/// The production implementation wraps [PermissionsHostApi]; tests
/// can provide a simple in-memory fake.
abstract interface class PermissionsApi {
  /// Check whether each permission string is currently granted.
  Future<Map<String, bool>> checkPermissions(List<String> permissions);

  /// Request the given permission strings from the user.
  Future<Map<String, bool>> requestPermissions(List<String> permissions);

  /// For each denied permission, whether the system can show a rationale
  /// dialog (i.e. the user did NOT check "Don't ask again").
  Future<Map<String, bool>> shouldShowRequestPermissionRationale(
    List<String> permissions,
  );

  /// Whether the given Android app role is currently held.
  Future<bool> isRoleHeld(String roleId);

  /// Request the user to grant the given Android app role.
  Future<bool> requestRole(String roleId);

  /// Whether the app is exempt from battery optimizations.
  Future<bool> isIgnoringBatteryOptimizations();

  /// Request exemption from battery optimizations (shows system dialog).
  Future<bool> requestIgnoreBatteryOptimizations();

  /// Open the system app-settings page for this app.
  Future<bool> openAppSettings();

  /// Whether the host can schedule exact alarms (API 31+ semantics).
  Future<bool> canScheduleExactAlarms();

  /// Request permission to schedule exact alarms.
  Future<bool> requestScheduleExactAlarms();

  /// Whether the host can install packages from unknown sources (API 26+).
  Future<bool> canRequestInstallPackages();

  /// Request the install-packages permission via settings screen.
  Future<bool> requestInstallPackages();

  /// Whether the host can draw overlays on top of other apps (API 23+).
  Future<bool> canDrawOverlays();

  /// Request overlay permission through system settings.
  Future<bool> requestDrawOverlays();

  /// Whether the host has MANAGE_EXTERNAL_STORAGE access (API 30+).
  Future<bool> canManageExternalStorage();

  /// Request MANAGE_EXTERNAL_STORAGE through system settings.
  Future<bool> requestManageExternalStorage();

  /// Reads the current Android API level reported by the host.
  Future<int> getSdkVersion();
}
