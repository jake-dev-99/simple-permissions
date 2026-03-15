import CoreBluetooth

final class BluetoothPermissionHandler: NSObject, PermissionHandler, CBCentralManagerDelegate {
  private var centralManager: CBCentralManager?
  private var pendingCompletion: ((String) -> Void)?

  var isSupported: Bool {
    if #available(iOS 13.0, *) {
      return true
    }
    return false
  }

  func check(completion: @escaping (String) -> Void) {
    guard #available(iOS 13.0, *) else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }
    completion(mapBluetoothStatus(CBManager.authorization))
  }

  func request(completion: @escaping (String) -> Void) {
    guard #available(iOS 13.0, *) else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }

    switch CBManager.authorization {
    case .allowedAlways:
      completion(GrantWire.granted.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      ensureMainThread {
        self.pendingCompletion = completion
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard let completion = pendingCompletion else { return }
    guard #available(iOS 13.0, *) else {
      completion(GrantWire.notAvailable.rawValue)
      pendingCompletion = nil
      centralManager = nil
      return
    }

    let status = CBManager.authorization
    guard status != .notDetermined else { return }
    completion(mapBluetoothStatus(status))
    pendingCompletion = nil
    centralManager = nil
  }

  @available(iOS 13.0, *)
  private func mapBluetoothStatus(_ status: CBManagerAuthorization) -> String {
    switch status {
    case .allowedAlways: return GrantWire.granted.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}
