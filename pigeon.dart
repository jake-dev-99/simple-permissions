/// Pigeon definition for simple_permissions plugin.
///
/// Regenerate with:
/// ```bash
/// dart run pigeon --input pigeon.dart
/// ```
library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/permissions.g.dart',
    kotlinOut:
        'android/src/main/kotlin/io/simplezen/simple_permissions/Permissions.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'io.simplezen.simple_permissions',
    ),
  ),
)

/// Host API for permission operations.
///
/// Implemented in Kotlin, called from Dart.
@HostApi()
abstract class PermissionsHostApi {
  /// Checks which permissions from the list are currently granted.
  ///
  /// Returns a map of permission string → granted status.
  Map<String, bool> checkPermissions(List<String> permissions);

  /// Requests the specified permissions from the user.
  ///
  /// Shows system permission dialogs. Returns map of permission → granted.
  /// This is async because it waits for user interaction.
  @async
  Map<String, bool> requestPermissions(List<String> permissions);

  /// Checks if the specified role is currently held by this app.
  ///
  /// Common roles:
  /// - `android.app.role.SMS` - Default SMS app
  /// - `android.app.role.DIALER` - Default phone app
  bool isRoleHeld(String roleId);

  /// Requests the specified role from the user.
  ///
  /// Shows system role request dialog. Returns true if granted.
  @async
  bool requestRole(String roleId);

  /// Checks if the app is exempt from battery optimization.
  ///
  /// Battery optimization exemption is important for SMS apps to ensure
  /// reliable message delivery when the phone is idle.
  bool isIgnoringBatteryOptimizations();

  /// Requests exemption from battery optimization.
  ///
  /// Shows system dialog explaining the request. Returns true if granted.
  @async
  bool requestIgnoreBatteryOptimizations();
}
