import CoreLocation

enum LocationPermissionLevel {
  case whenInUse
  case always
}

final class LocationPermissionHandler: NSObject, PermissionHandler, CLLocationManagerDelegate {
  let level: LocationPermissionLevel
  private var manager: CLLocationManager?
  private var pendingCompletion: ((String) -> Void)?

  init(level: LocationPermissionLevel) {
    self.level = level
  }

  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let manager = CLLocationManager()
    completion(mapLocationStatus(manager.authorizationStatus))
  }

  func request(completion: @escaping (String) -> Void) {
    ensureMainThread {
      let manager = CLLocationManager()
      let status = manager.authorizationStatus

      switch status {
      case .authorizedAlways:
        completion(GrantWire.granted.rawValue)
        return
      case .authorizedWhenInUse:
        if self.level == .whenInUse {
          completion(GrantWire.granted.rawValue)
          return
        }
      case .denied:
        completion(GrantWire.permanentlyDenied.rawValue)
        return
      case .restricted:
        completion(GrantWire.restricted.rawValue)
        return
      case .notDetermined:
        break
      @unknown default:
        completion(GrantWire.denied.rawValue)
        return
      }

      self.manager = manager
      self.pendingCompletion = completion
      manager.delegate = self

      switch self.level {
      case .whenInUse:
        manager.requestWhenInUseAuthorization()
      case .always:
        manager.requestAlwaysAuthorization()
      }
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let completion = pendingCompletion else { return }
    let status = manager.authorizationStatus
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
    case .authorizedWhenInUse:
      return level == .whenInUse
        ? GrantWire.granted.rawValue
        : GrantWire.limited.rawValue
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
