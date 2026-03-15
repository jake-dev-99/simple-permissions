import EventKit

func buildPermissionHandlerRegistry() -> [String: PermissionHandler] {
  [
    "read_contacts": ContactsPermissionHandler(),
    "write_contacts": ContactsPermissionHandler(),
    "camera_access": CameraPermissionHandler(),
    "record_audio": MicrophonePermissionHandler(),
    "read_media_images": PhotoLibraryPermissionHandler(),
    "read_media_video": PhotoLibraryPermissionHandler(),
    "post_notifications": NotificationPermissionHandler(),
    "coarse_location": LocationPermissionHandler(),
    "fine_location": LocationPermissionHandler(),
    "read_calendar": CalendarPermissionHandler(entityType: .event),
    "write_calendar": CalendarPermissionHandler(entityType: .event),
    "read_reminders": CalendarPermissionHandler(entityType: .reminder),
    "write_reminders": CalendarPermissionHandler(entityType: .reminder),
  ]
}
