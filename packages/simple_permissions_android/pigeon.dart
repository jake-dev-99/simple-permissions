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

        Map<String, bool> shouldShowRequestPermissionRationale(
    List<String> permissions,
  );

        bool openAppSettings();
}
