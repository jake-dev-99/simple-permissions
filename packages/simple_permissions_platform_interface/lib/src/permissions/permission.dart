/// The complete permission type hierarchy for simple_permissions.
///
/// This library defines [Permission] as a sealed class root, with domain-
/// specific sealed subtrees (camera, location, contacts, etc.) and
/// [VersionedPermission] for OS-version-dependent resolution.
///
/// All types are const-constructible and use [identifier] for equality.
library;

part 'bluetooth.dart';
part 'calendar.dart';
part 'camera.dart';
part 'contacts.dart';
part 'health.dart';
part 'location.dart';
part 'messaging.dart';
part 'microphone.dart';
part 'notification.dart';
part 'phone.dart';
part 'role.dart';
part 'sensor.dart';
part 'speech.dart';
part 'storage.dart';
part 'system.dart';
part 'tracking.dart';
part 'versioned_permission.dart';
part 'wifi.dart';

/// Base sealed class for all permissions in the simple_permissions system.
///
/// Each permission domain (camera, location, contacts, etc.) extends this
/// class with its own sealed hierarchy. Platform implementations use
/// [identifier] to look up the correct native handler.
///
/// All concrete permission types are const-constructible value objects.
sealed class Permission {
  const Permission();

  /// Platform-agnostic identifier for this permission.
  ///
  /// Each platform implementation maps this to the native permission string
  /// or API call. For example, `'read_contacts'` maps to
  /// `android.permission.READ_CONTACTS` on Android and
  /// `CNAuthorizationStatus` on iOS.
  String get identifier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Permission && other.identifier == identifier;

  @override
  int get hashCode => identifier.hashCode;

  @override
  String toString() => '$runtimeType($identifier)';
}
