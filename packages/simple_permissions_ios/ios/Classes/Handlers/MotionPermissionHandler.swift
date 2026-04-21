import CoreMotion

/// Motion-activity permission backed by `CMMotionActivityManager`.
///
/// iOS has no dedicated "request motion permission" API — the prompt
/// is triggered as a side effect of the first `queryActivityStarting`
/// call. Both the status read and the prompt-and-read dance live in
/// `PermissionGuards`; this handler is a thin registry adapter.
///
/// `isSupported` still gates on `CMMotionActivityManager.isActivityAvailable()`
/// so devices without motion hardware report `.notAvailable` before
/// ever calling the authorization APIs.
final class MotionPermissionHandler: PermissionHandler {
  var isSupported: Bool { CMMotionActivityManager.isActivityAvailable() }

  func check(completion: @escaping (String) -> Void) {
    completion(PermissionGuards.authorizationStatus(for: .motion).rawValue)
  }

  func request(completion: @escaping (String) -> Void) {
    Task {
      let grant = await PermissionGuards.requestAuthorization(for: .motion)
      ensureMainThread { completion(grant.rawValue) }
    }
  }
}
