import AppTrackingTransparency

final class TrackingPermissionHandler: PermissionHandler {
  var isSupported: Bool {
    if #available(iOS 14.0, *) {
      return true
    }
    return false
  }

  func check(completion: @escaping (String) -> Void) {
    if #available(iOS 14.0, *) {
      completion(mapTrackingStatus(ATTrackingManager.trackingAuthorizationStatus))
    } else {
      completion(GrantWire.notAvailable.rawValue)
    }
  }

  func request(completion: @escaping (String) -> Void) {
    if #available(iOS 14.0, *) {
      switch ATTrackingManager.trackingAuthorizationStatus {
      case .authorized:
        completion(GrantWire.granted.rawValue)
      case .denied:
        completion(GrantWire.permanentlyDenied.rawValue)
      case .restricted:
        completion(GrantWire.restricted.rawValue)
      case .notDetermined:
        ATTrackingManager.requestTrackingAuthorization { status in
          ensureMainThread {
            completion(self.mapTrackingStatus(status))
          }
        }
      @unknown default:
        completion(GrantWire.denied.rawValue)
      }
    } else {
      completion(GrantWire.notAvailable.rawValue)
    }
  }

  @available(iOS 14.0, *)
  private func mapTrackingStatus(_ status: ATTrackingManager.AuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}
