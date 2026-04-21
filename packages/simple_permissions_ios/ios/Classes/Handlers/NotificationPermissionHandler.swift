import Foundation

/// Notifications authorization adapter. Both the status read and the
/// request prompt are async-only on UNUserNotificationCenter; the
/// actual framework interaction lives in `PermissionGuards`.
final class NotificationPermissionHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    Task {
      let grant = await PermissionGuards.notificationsStatus()
      ensureMainThread { completion(grant.rawValue) }
    }
  }

  func request(completion: @escaping (String) -> Void) {
    Task {
      let grant = await PermissionGuards.requestNotificationsAuthorization()
      ensureMainThread { completion(grant.rawValue) }
    }
  }
}
