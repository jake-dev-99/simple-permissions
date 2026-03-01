library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/permissions.g.dart',
    kotlinOut:
        'android/src/main/kotlin/io/simplezen/simple_permissions_android/Permissions.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'io.simplezen.simple_permissions_android',
    ),
  ),
)
@HostApi()
abstract class PermissionsHostApi {
  Map<String, bool> checkPermissions(List<String> permissions);

  @async
  Map<String, bool> requestPermissions(List<String> permissions);

  bool isRoleHeld(String roleId);

  @async
  bool requestRole(String roleId);

  bool isIgnoringBatteryOptimizations();

  @async
  bool requestIgnoreBatteryOptimizations();

  /// Whether the host can schedule exact alarms (API 31+).
  bool canScheduleExactAlarms();

  @async
  bool requestScheduleExactAlarms();

  /// Whether the host may install packages from unknown sources (API 26+).
  bool canRequestInstallPackages();

  @async
  bool requestInstallPackages();

  /// Whether the host can draw overlays on top of other apps (API 23+).
  bool canDrawOverlays();

  @async
  bool requestDrawOverlays();

  /// Whether the host has MANAGE_EXTERNAL_STORAGE access (API 30+).
  bool canManageExternalStorage();

  @async
  bool requestManageExternalStorage();

  Map<String, bool> shouldShowRequestPermissionRationale(
    List<String> permissions,
  );

  /// Returns the current Android SDK level (Build.VERSION.SDK_INT).
  int getSdkVersion();

  bool openAppSettings();
}
