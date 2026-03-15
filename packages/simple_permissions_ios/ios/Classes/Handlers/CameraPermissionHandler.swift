import AVFoundation

final class CameraPermissionHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    completion(mapAVStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
      completion(GrantWire.granted.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        ensureMainThread {
          completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapAVStatus(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}
