import Foundation

/// Photo-library authorization adapter. Handles read-write access
/// by default; pass `.photoLibraryAddOnly` to gate on add-only.
final class PhotoLibraryPermissionHandler: PermissionHandler {
  let kind: MacOSPermissionKind

  init(kind: MacOSPermissionKind = .photoLibrary) {
    self.kind = kind
  }

  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    completion(PermissionGuards.authorizationStatus(for: kind).rawValue)
  }

  func request(completion: @escaping (String) -> Void) {
    let kind = self.kind
    Task {
      let grant = await PermissionGuards.requestAuthorization(for: kind)
      ensureMainThread { completion(grant.rawValue) }
    }
  }
}
