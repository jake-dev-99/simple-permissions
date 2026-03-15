import Foundation

// MARK: - Permission Grant Wire Values

/// Wire values sent back to Dart, matching PermissionGrant enum names.
enum GrantWire: String {
  case granted
  case denied
  case permanentlyDenied
  case restricted
  case limited
  case notApplicable
  case notAvailable
  case provisional
}

// MARK: - Permission Handler Protocol

/// All macOS permission handlers conform to this protocol.
protocol PermissionHandler {
  func check(completion: @escaping (String) -> Void)
  func request(completion: @escaping (String) -> Void)
  /// Whether this permission is supported on the running macOS version.
  var isSupported: Bool { get }
}

// MARK: - Thread Safety

func ensureMainThread(_ block: @escaping () -> Void) {
  if Thread.isMainThread {
    block()
  } else {
    DispatchQueue.main.async { block() }
  }
}
