part of 'permission.dart';

/// Permissions related to notifications.
sealed class NotificationPermission extends Permission {
  const NotificationPermission();
}

/// Post notifications to the user.
///
/// - **Android**: `android.permission.POST_NOTIFICATIONS` (API 33+)
/// - **iOS**: `UNAuthorizationStatus`
class PostNotifications extends NotificationPermission {
  const PostNotifications();

  @override
  String get identifier => 'post_notifications';
}
