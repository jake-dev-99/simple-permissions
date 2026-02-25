/// Represents different intentions for permission requests.
///
/// An intention groups related permissions and roles together for common
/// use cases like texting, calling, or accessing contacts.
///
/// ## Usage
///
/// ```dart
/// // Get all permissions for texting
/// final permissions = Intention.texting.permissions;
///
/// // Get the role (if any) for texting
/// final role = Intention.texting.role;  // 'android.app.role.SMS'
///
/// // Request all permissions for an intention
/// await SimplePermissions.instance.requestPermissions(
///   Intention.texting.permissions,
/// );
/// ```
enum Intention {
  /// SMS/MMS messaging - requires default SMS app role
  texting,

  /// Phone calls - requires default dialer role
  calling,

  /// Contact access
  contacts,

  /// Device information
  device,

  /// File/media access
  fileAccess,

  /// Notification posting (Android 13+)
  notifications;

  /// Get the Android role associated with this intention.
  ///
  /// Returns null if no role is required for this intention.
  /// Roles are system-level capabilities that only one app can hold
  /// at a time (e.g., default SMS app, default dialer).
  String? get role {
    switch (this) {
      case Intention.texting:
        return 'android.app.role.SMS';
      case Intention.calling:
        return 'android.app.role.DIALER';
      case Intention.contacts:
      case Intention.device:
      case Intention.fileAccess:
      case Intention.notifications:
        return null;
    }
  }

  /// Get the Android permissions associated with this intention.
  ///
  /// These are runtime permissions that must be granted by the user.
  List<String> get permissions {
    switch (this) {
      case Intention.texting:
        return const [
          'android.permission.SEND_SMS',
          'android.permission.READ_SMS',
          'android.permission.RECEIVE_SMS',
          'android.permission.RECEIVE_WAP_PUSH',
          'android.permission.RECEIVE_MMS',
        ];
      case Intention.calling:
        return const [
          'android.permission.READ_PHONE_STATE',
          'android.permission.READ_PHONE_NUMBERS',
          'android.permission.CALL_PHONE',
          'android.permission.ANSWER_PHONE_CALLS',
        ];
      case Intention.contacts:
        return const [
          'android.permission.READ_CONTACTS',
          'android.permission.WRITE_CONTACTS',
        ];
      case Intention.device:
        return const [
          'android.permission.READ_PHONE_STATE',
        ];
      case Intention.fileAccess:
        return const [
          // API < 33
          'android.permission.READ_EXTERNAL_STORAGE',
          // API >= 33
          'android.permission.READ_MEDIA_IMAGES',
          'android.permission.READ_MEDIA_VIDEO',
          'android.permission.READ_MEDIA_AUDIO',
        ];
      case Intention.notifications:
        return const [
          'android.permission.POST_NOTIFICATIONS',
        ];
    }
  }

  /// Whether this intention requires a role to function fully.
  bool get requiresRole => role != null;
}
