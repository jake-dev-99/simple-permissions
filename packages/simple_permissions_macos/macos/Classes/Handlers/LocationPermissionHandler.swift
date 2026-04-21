import Foundation

/// Location authorization adapter. macOS has only an "always"
/// authorization model (no WhenInUse equivalent), so the handler
/// delegates straight through to `.location` — no level parameter
/// needed. All delegate plumbing for the first-time prompt lives in
/// `PermissionGuards`.
final class LocationPermissionHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    completion(PermissionGuards.authorizationStatus(for: .location).rawValue)
  }

  func request(completion: @escaping (String) -> Void) {
    Task {
      let grant = await PermissionGuards.requestAuthorization(for: .location)
      ensureMainThread { completion(grant.rawValue) }
    }
  }
}
