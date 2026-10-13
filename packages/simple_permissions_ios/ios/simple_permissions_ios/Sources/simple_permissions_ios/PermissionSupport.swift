import Foundation

// MARK: - Permission Handler Protocol

/// All iOS permission handlers conform to this protocol.
///
/// Handlers are thin adapters between the registry (string
/// identifiers from the Dart side, via Pigeon) and `PermissionGuards`.
/// Each handler wires a specific permission identifier to the
/// corresponding `ApplePermissionKind`; the actual framework
/// interaction — status read, request prompt, delegate dance —
/// lives in `PermissionGuards.swift`.
///
/// The wire format on the completion (`String`) matches
/// `PermissionGrant.rawValue`: `"granted"`, `"denied"`,
/// `"permanentlyDenied"`, `"restricted"`, `"limited"`,
/// `"notApplicable"`, `"notAvailable"`, `"provisional"`. Handlers
/// produce these by calling `PermissionGuards.*.rawValue`.
protocol PermissionHandler {
  func check(completion: @escaping (String) -> Void)
  func request(completion: @escaping (String) -> Void)
  /// Whether this permission is supported on the running iOS version.
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
