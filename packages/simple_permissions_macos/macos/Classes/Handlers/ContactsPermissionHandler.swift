import Foundation

final class ContactsPermissionHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    completion(PermissionGuards.authorizationStatus(for: .contacts).rawValue)
  }

  func request(completion: @escaping (String) -> Void) {
    Task {
      let grant = await PermissionGuards.requestAuthorization(for: .contacts)
      ensureMainThread { completion(grant.rawValue) }
    }
  }
}
