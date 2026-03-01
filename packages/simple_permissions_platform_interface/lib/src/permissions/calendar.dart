part of 'permission.dart';

/// Permissions related to calendar access.
sealed class CalendarPermission extends Permission {
  const CalendarPermission();
}

/// Read calendar events.
///
/// - **Android**: `android.permission.READ_CALENDAR`
/// - **iOS**: `EKAuthorizationStatus` for `.event`
/// - **macOS**: `EKAuthorizationStatus` for `.event`
class ReadCalendar extends CalendarPermission {
  const ReadCalendar();

  @override
  String get identifier => 'read_calendar';
}

/// Create/modify calendar events.
///
/// - **Android**: `android.permission.WRITE_CALENDAR`
/// - **iOS**: Included in calendar authorization (same as read)
class WriteCalendar extends CalendarPermission {
  const WriteCalendar();

  @override
  String get identifier => 'write_calendar';
}
