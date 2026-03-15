import UserNotifications

final class NotificationPermissionHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      ensureMainThread {
        completion(self.mapNotificationStatus(settings.authorizationStatus))
      }
    }
  }

  func request(completion: @escaping (String) -> Void) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, _ in
      if granted {
        ensureMainThread { completion(GrantWire.granted.rawValue) }
        return
      }
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        ensureMainThread {
          let wire = settings.authorizationStatus == .denied
            ? GrantWire.permanentlyDenied.rawValue
            : GrantWire.denied.rawValue
          completion(wire)
        }
      }
    }
  }

  private func mapNotificationStatus(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .provisional: return GrantWire.provisional.rawValue
    case .ephemeral: return GrantWire.provisional.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}
