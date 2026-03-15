import CoreLocation

final class LocationPermissionHandler: NSObject, PermissionHandler, CLLocationManagerDelegate {
  private var manager: CLLocationManager?
  private var pendingCompletion: ((String) -> Void)?

  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let manager = CLLocationManager()
    let status: CLAuthorizationStatus
    if #available(macOS 11.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    completion(mapLocationStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    ensureMainThread {
      let manager = CLLocationManager()
      let status: CLAuthorizationStatus
      if #available(macOS 11.0, *) {
        status = manager.authorizationStatus
      } else {
        status = CLLocationManager.authorizationStatus()
      }

      switch status {
      case .authorizedAlways:
        completion(GrantWire.granted.rawValue)
        return
      case .denied:
        completion(GrantWire.permanentlyDenied.rawValue)
        return
      case .restricted:
        completion(GrantWire.restricted.rawValue)
        return
      case .notDetermined:
        break
      default:
        completion(GrantWire.denied.rawValue)
        return
      }

      self.manager = manager
      self.pendingCompletion = completion
      manager.delegate = self
      manager.requestAlwaysAuthorization()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let completion = pendingCompletion else { return }
    let status: CLAuthorizationStatus
    if #available(macOS 11.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    guard status != .notDetermined else { return }

    ensureMainThread {
      completion(self.mapLocationStatus(status))
      self.pendingCompletion = nil
      self.manager = nil
    }
  }

  private func mapLocationStatus(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .authorizedAlways:
      return GrantWire.granted.rawValue
    case .notDetermined:
      return GrantWire.denied.rawValue
    case .denied:
      return GrantWire.permanentlyDenied.rawValue
    case .restricted:
      return GrantWire.restricted.rawValue
    @unknown default:
      return GrantWire.denied.rawValue
    }
  }
}
