import 'permissions/permissions.dart';

/// A high-level grouping of [Permission]s that together enable a user-facing
/// feature.
///
/// Instead of managing individual permissions, express what the app **intends
/// to do** and let the plugin resolve the correct permission set:
///
/// ```dart
/// // Request everything needed for SMS messaging
/// final result = await SimplePermissions.instance.requestIntention(
///   Intention.texting,
/// );
/// ```
///
/// ## Built-in intentions
///
/// - [Intention.texting] — SMS/MMS messaging (role + permissions)
/// - [Intention.calling] — Phone/dialer (role + permissions)
/// - [Intention.contacts] — Read/write contacts
/// - [Intention.device] — Phone state and device info
/// - [Intention.mediaImages] — Photo/image access (version-aware)
/// - [Intention.mediaVideo] — Video access (version-aware)
/// - [Intention.mediaAudio] — Audio file access (version-aware)
/// - [Intention.notifications] — Post notifications
/// - [Intention.location] — Fine + coarse location
/// - [Intention.camera] — Camera access
/// - [Intention.microphone] — Audio recording
///
/// ## Custom intentions
///
/// Consuming apps can compose custom intentions:
///
/// ```dart
/// const myFeature = Intention('video_call', [
///   CameraAccess(),
///   RecordAudio(),
///   FineLocation(),
/// ]);
/// ```
class Intention {
  const Intention(this.name, this.permissions);

  /// Human-readable name for this intention (used in logging/debugging).
  final String name;

  /// The permissions required to fulfill this intention.
  ///
  /// May include [VersionedPermission] instances, which the platform
  /// implementation will resolve to the correct concrete permission for
  /// the running OS version.
  final List<Permission> permissions;

  // ===========================================================================
  // Built-in intentions
  // ===========================================================================

  /// SMS/MMS messaging — become default SMS app + all messaging permissions.
  static const texting = Intention('texting', [
    DefaultSmsApp(),
    SendSms(),
    ReadSms(),
    ReceiveSms(),
    ReceiveMms(),
    ReceiveWapPush(),
  ]);

  /// Phone/dialer — become default dialer + call-related permissions.
  static const calling = Intention('calling', [
    DefaultDialerApp(),
    ReadPhoneState(),
    ReadPhoneNumbers(),
    MakeCalls(),
    AnswerCalls(),
  ]);

  /// Contact access — read and write the device contact book.
  static const contacts = Intention('contacts', [
    ReadContacts(),
    WriteContacts(),
  ]);

  /// Device info — phone state, phone numbers.
  static const device = Intention('device', [
    ReadPhoneState(),
    ReadPhoneNumbers(),
  ]);

  /// Image/photo access — version-aware (API 33 split handled automatically).
  static const mediaImages = Intention('media_images', [
    VersionedPermission.images(),
  ]);

  /// Video access — version-aware (API 33 split handled automatically).
  static const mediaVideo = Intention('media_video', [
    VersionedPermission.video(),
  ]);

  /// Audio file access — version-aware (API 33 split handled automatically).
  static const mediaAudio = Intention('media_audio', [
    VersionedPermission.audio(),
  ]);

  /// All visual media (images + video) — version-aware.
  static const mediaVisual = Intention('media_visual', [
    VersionedPermission.images(),
    VersionedPermission.video(),
  ]);

  /// Notifications — post notifications to the user.
  static const notifications = Intention('notifications', [
    PostNotifications(),
  ]);

  /// Location — fine and coarse location.
  static const location = Intention('location', [
    FineLocation(),
    CoarseLocation(),
  ]);

  /// Camera access.
  static const camera = Intention('camera', [
    CameraAccess(),
  ]);

  /// Microphone / audio recording.
  static const microphone = Intention('microphone', [
    RecordAudio(),
  ]);

  /// Combine multiple intentions into one.
  ///
  /// ```dart
  /// final videoCall = Intention.combine('video_call', [
  ///   Intention.camera,
  ///   Intention.microphone,
  ///   Intention.location,
  /// ]);
  /// ```
  factory Intention.combine(String name, List<Intention> intentions) {
    final allPermissions = <Permission>[];
    final seen = <String>{};
    for (final intention in intentions) {
      for (final permission in intention.permissions) {
        if (seen.add(permission.identifier)) {
          allPermissions.add(permission);
        }
      }
    }
    return Intention(name, allPermissions);
  }

  @override
  String toString() => 'Intention($name, ${permissions.length} permissions)';
}
