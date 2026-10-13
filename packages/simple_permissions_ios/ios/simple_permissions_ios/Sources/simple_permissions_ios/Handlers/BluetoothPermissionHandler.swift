import Foundation

/// Bluetooth authorization adapter. All framework interaction —
/// status query, delegate dance for the request-on-first-init
/// prompt — lives in `PermissionGuards`; this handler is a thin
/// registry adapter.
final class BluetoothPermissionHandler: PermissionHandler {
  var isSupported: Bool {
    if #available(iOS 13.0, *) {
      return true
    }
    return false
  }

  func check(completion: @escaping (String) -> Void) {
    completion(PermissionGuards.authorizationStatus(for: .bluetooth).rawValue)
  }

  func request(completion: @escaping (String) -> Void) {
    Task {
      let grant = await PermissionGuards.requestAuthorization(for: .bluetooth)
      ensureMainThread { completion(grant.rawValue) }
    }
  }
}
