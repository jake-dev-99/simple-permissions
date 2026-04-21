import Foundation

/// Photo-library authorization adapter. Handles the read-write
/// access level. The add-only level is registered separately via
/// `.photoLibraryAddOnly` and uses the same handler shape with a
/// different kind.
final class PhotoLibraryPermissionHandler: PermissionHandler {
  /// `.photoLibrary` (read-write) or `.photoLibraryAddOnly`. Allows
  /// one handler class to serve both registrations.
  let kind: ApplePermissionKind

  init(kind: ApplePermissionKind = .photoLibrary) {
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
