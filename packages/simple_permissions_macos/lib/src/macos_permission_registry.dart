import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

/// Configuration for how a [Permission] maps to macOS native handling.
class MacosPermissionMapping {
  const MacosPermissionMapping(this.identifier);

  /// The identifier string sent to the Swift handler registry.
  /// Matches [Permission.identifier].
  final String identifier;
}

/// Set of Permission types that have native macOS handlers.
///
/// Permissions not in this set return [PermissionGrant.notApplicable].
/// The identifier-based Pigeon API means the Swift side decides actual
/// authorization status; this registry just gates which identifiers
/// are valid to send.
///
/// macOS-supported permission identifiers:
/// - Contacts: read_contacts, write_contacts
/// - Camera: camera_access
/// - Microphone: record_audio
/// - Photos: read_media_images, read_media_video
/// - Notifications: post_notifications
/// - Location: coarse_location, fine_location
/// - Calendar: read_calendar, write_calendar, read_reminders, write_reminders
///
/// Not applicable on macOS (iOS-only or Android-only):
/// - BackgroundLocation, Health, BodySensors, ActivityRecognition,
///   AppTrackingTransparency, SMS/MMS, Phone/Calls, Storage, Bluetooth, etc.
const Map<Type, MacosPermissionMapping> _macosRegistry = {
  // Contacts
  ReadContacts: MacosPermissionMapping('read_contacts'),
  WriteContacts: MacosPermissionMapping('write_contacts'),

  // Camera
  CameraAccess: MacosPermissionMapping('camera_access'),

  // Microphone
  RecordAudio: MacosPermissionMapping('record_audio'),

  // Photos / Media (macOS uses PHPhotoLibrary for images and video)
  ReadMediaImages: MacosPermissionMapping('read_media_images'),
  ReadMediaVideo: MacosPermissionMapping('read_media_video'),

  // Notifications (macOS 10.14+)
  PostNotifications: MacosPermissionMapping('post_notifications'),

  // Location (CoreLocation on macOS — no background location concept)
  CoarseLocation: MacosPermissionMapping('coarse_location'),
  FineLocation: MacosPermissionMapping('fine_location'),

  // Calendar (EventKit)
  ReadCalendar: MacosPermissionMapping('read_calendar'),
  WriteCalendar: MacosPermissionMapping('write_calendar'),
  ReadReminders: MacosPermissionMapping('read_reminders'),
  WriteReminders: MacosPermissionMapping('write_reminders'),
};

/// Look up the macOS mapping for a [Permission] type.
///
/// Returns `null` if this permission has no macOS equivalent (mobile-only
/// concepts like SMS, telephony, health, sensors, tracking, etc.).
MacosPermissionMapping? macosPermissionMapping(Type permissionType) =>
    _macosRegistry[permissionType];

/// Whether the given [Permission] type has a registered macOS handler.
bool isMacosPermissionRegistered(Type permissionType) =>
    _macosRegistry.containsKey(permissionType);
