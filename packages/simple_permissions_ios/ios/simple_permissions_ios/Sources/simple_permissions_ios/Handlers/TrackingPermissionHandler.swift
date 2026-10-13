import Foundation

final class TrackingPermissionHandler: PermissionHandler {
  var isSupported: Bool {
    if #available(iOS 14.0, *) {
      return true
    }
    return false
  }

  func check(completion: @escaping (String) -> Void) {
    completion(PermissionGuards.authorizationStatus(for: .tracking).rawValue)
  }

  func request(completion: @escaping (String) -> Void) {
    Task {
      let grant = await PermissionGuards.requestAuthorization(for: .tracking)
      ensureMainThread { completion(grant.rawValue) }
    }
  }
}
