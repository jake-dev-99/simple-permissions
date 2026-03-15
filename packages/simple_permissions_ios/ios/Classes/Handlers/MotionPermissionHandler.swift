import CoreMotion

final class MotionPermissionHandler: PermissionHandler {
  var isSupported: Bool { CMMotionActivityManager.isActivityAvailable() }

  func check(completion: @escaping (String) -> Void) {
    guard CMMotionActivityManager.isActivityAvailable() else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }

    let manager = CMMotionActivityManager()
    let now = Date()
    manager.queryActivityStarting(from: now, to: now, to: .main) { _, error in
      if let error = error as NSError? {
        if error.domain == CMErrorDomain
          && error.code == CMError.motionActivityNotAuthorized.rawValue
        {
          completion(GrantWire.permanentlyDenied.rawValue)
        } else if error.domain == CMErrorDomain
          && error.code == CMError.motionActivityNotEntitled.rawValue
        {
          completion(GrantWire.restricted.rawValue)
        } else {
          completion(GrantWire.denied.rawValue)
        }
      } else {
        completion(GrantWire.granted.rawValue)
      }
      manager.stopActivityUpdates()
    }
  }

  func request(completion: @escaping (String) -> Void) {
    check(completion: completion)
  }
}
