import Foundation

final class CameraPermissionHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    completion(PermissionGuards.authorizationStatus(for: .camera).rawValue)
  }

  func request(completion: @escaping (String) -> Void) {
    Task {
      let grant = await PermissionGuards.requestAuthorization(for: .camera)
      ensureMainThread { completion(grant.rawValue) }
    }
  }
}
