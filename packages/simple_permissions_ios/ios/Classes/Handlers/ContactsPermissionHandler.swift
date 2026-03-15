import Contacts

final class ContactsPermissionHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    completion(mapContactsStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    switch status {
    case .authorized:
      completion(GrantWire.granted.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      CNContactStore().requestAccess(for: .contacts) { granted, _ in
        ensureMainThread {
          completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapContactsStatus(_ status: CNAuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}
