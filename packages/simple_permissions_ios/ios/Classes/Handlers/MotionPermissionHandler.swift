import CoreMotion

/// Motion-activity permission backed by `CMMotionActivityManager`.
///
/// iOS has no dedicated "request motion permission" API — the prompt
/// is triggered as a side effect of the first `queryActivityStarting`
/// call against the manager. `check` uses the non-prompting
/// `CMMotionActivityManager.authorizationStatus()` (iOS 11+); `request`
/// fires a throwaway query to trigger the system prompt, then re-reads
/// the status once the query callback fires.
///
/// Previous revision tried to decode the query's `NSError` against
/// `CMError.motionActivityNotAuthorized` / `.motionActivityNotEntitled`,
/// but the Swift bridging of those enum cases isn't stable across
/// recent Xcode SDKs — CI on simulator fails with
/// `Type 'CMError' has no member 'motionActivityNotAuthorized'`. The
/// `authorizationStatus()` path is both more robust and more
/// straightforward.
final class MotionPermissionHandler: PermissionHandler {
  var isSupported: Bool { CMMotionActivityManager.isActivityAvailable() }

  func check(completion: @escaping (String) -> Void) {
    guard CMMotionActivityManager.isActivityAvailable() else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }
    completion(mapStatus(CMMotionActivityManager.authorizationStatus()))
  }

  func request(completion: @escaping (String) -> Void) {
    guard CMMotionActivityManager.isActivityAvailable() else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }

    let current = CMMotionActivityManager.authorizationStatus()
    switch current {
    case .authorized, .denied, .restricted:
      // Already answered. Re-prompting is a no-op on iOS anyway —
      // return the current mapping so the UI can route to Settings
      // for denied/restricted paths.
      completion(mapStatus(current))
    case .notDetermined:
      // Fire a throwaway query to trigger the prompt. The callback
      // fires after the user answers; re-read authorization status
      // rather than trying to decode the query error.
      let manager = CMMotionActivityManager()
      let now = Date()
      manager.queryActivityStarting(from: now, to: now, to: .main) { _, _ in
        ensureMainThread {
          completion(mapStatus(CMMotionActivityManager.authorizationStatus()))
          manager.stopActivityUpdates()
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapStatus(_ status: CMAuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}
