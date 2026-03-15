import EventKit

final class CalendarPermissionHandler: PermissionHandler {
  let entityType: EKEntityType

  init(entityType: EKEntityType) {
    self.entityType = entityType
  }

  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    completion(mapCalendarStatus(EKEventStore.authorizationStatus(for: entityType)))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = EKEventStore.authorizationStatus(for: entityType)
    switch status {
    case .authorized, .fullAccess:
      completion(GrantWire.granted.rawValue)
    case .writeOnly:
      completion(GrantWire.limited.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      if #available(iOS 17.0, *) {
        let store = EKEventStore()
        switch entityType {
        case .event:
          store.requestFullAccessToEvents { granted, _ in
            ensureMainThread {
              completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
            }
          }
        case .reminder:
          store.requestFullAccessToReminders { granted, _ in
            ensureMainThread {
              completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
            }
          }
        @unknown default:
          store.requestAccess(to: entityType) { granted, _ in
            ensureMainThread {
              completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
            }
          }
        }
      } else {
        EKEventStore().requestAccess(to: entityType) { granted, _ in
          ensureMainThread {
            completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
          }
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapCalendarStatus(_ status: EKAuthorizationStatus) -> String {
    switch status {
    case .authorized, .fullAccess: return GrantWire.granted.rawValue
    case .writeOnly: return GrantWire.limited.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}
