library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/permissions_ios.g.dart',
    swiftOut: 'ios/Classes/PermissionsIos.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)

/// Host API for iOS permission operations.
///
/// Uses permission `identifier` strings (matching [Permission.identifier])
/// to avoid coupling native code to any specific Dart type hierarchy.
/// The Swift side uses a handler registry keyed on these identifiers.
@HostApi()
abstract class PermissionsIosHostApi {
  /// Check the current authorization status for a permission.
  ///
  /// Returns a wire string: "granted", "denied", "permanentlyDenied",
  /// "restricted", "limited", "notApplicable", "notAvailable", "provisional".
  @async
  String checkPermission(String identifier);

  /// Request authorization for a permission.
  ///
  /// Returns a wire string with the same values as [checkPermission].
  @async
  String requestPermission(String identifier);

  /// Whether the given permission identifier is supported on this device/OS version.
  bool isSupported(String identifier);

  /// Open this app's settings page in the Settings app.
  @async
  bool openAppSettings();
}
