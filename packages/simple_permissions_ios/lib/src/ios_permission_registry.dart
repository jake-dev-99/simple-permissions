import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

/// Configuration for how a [Permission] maps to iOS native handling.
class IosPermissionMapping {
  const IosPermissionMapping(this.identifier);

  /// The identifier string sent to the Swift handler registry.
  /// Matches [Permission.identifier].
  final String identifier;
}

/// Set of Permission types that have native iOS handlers.
///
/// Permissions not in this set return [PermissionGrant.notApplicable].
/// The identifier-based Pigeon API means the Swift side decides actual
/// authorization status; this registry just gates which identifiers
/// are valid to send.
///
/// iOS-supported permission identifiers:
/// - Contacts: read_contacts, write_contacts
/// - Camera: camera_access
/// - Microphone: record_audio
/// - Photos: read_media_images, read_media_video
/// - Notifications: post_notifications
/// - Location: coarse_location, fine_location, background_location
/// - Calendar: read_calendar, write_calendar
/// - Health: read_health, write_health
/// - Sensors: body_sensors, activity_recognition
/// - Tracking: app_tracking_transparency
const Map<Type, IosPermissionMapping> _iosRegistry = {
  // Contacts
  ReadContacts: IosPermissionMapping('read_contacts'),
  WriteContacts: IosPermissionMapping('write_contacts'),

  // Camera
  CameraAccess: IosPermissionMapping('camera_access'),

  // Microphone
  RecordAudio: IosPermissionMapping('record_audio'),

  // Photos / Media (iOS uses PHPhotoLibrary for images and video)
  ReadMediaImages: IosPermissionMapping('read_media_images'),
  ReadMediaVideo: IosPermissionMapping('read_media_video'),

  // Notifications
  PostNotifications: IosPermissionMapping('post_notifications'),

  // Location
  CoarseLocation: IosPermissionMapping('coarse_location'),
  FineLocation: IosPermissionMapping('fine_location'),
  BackgroundLocation: IosPermissionMapping('background_location'),

  // Calendar
  ReadCalendar: IosPermissionMapping('read_calendar'),
  WriteCalendar: IosPermissionMapping('write_calendar'),

  // Health (HealthKit)
  ReadHealth: IosPermissionMapping('read_health'),
  WriteHealth: IosPermissionMapping('write_health'),

  // Sensors / Motion
  BodySensors: IosPermissionMapping('body_sensors'),
  ActivityRecognition: IosPermissionMapping('activity_recognition'),

  // Tracking (ATT)
  AppTrackingTransparency: IosPermissionMapping('app_tracking_transparency'),
};

/// Look up the iOS mapping for a [Permission] type.
///
/// Returns `null` if this permission has no iOS equivalent (Android-only
/// concepts like roles, SMS sending, battery optimization, etc.).
IosPermissionMapping? iosPermissionMapping(Type permissionType) =>
    _iosRegistry[permissionType];

/// Whether the given [Permission] type has a registered iOS handler.
bool isIosPermissionRegistered(Type permissionType) =>
    _iosRegistry.containsKey(permissionType);
