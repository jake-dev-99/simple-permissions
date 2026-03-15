import AVFoundation

final class MicrophonePermissionHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let status = AVAudioSession.sharedInstance().recordPermission
    completion(mapRecordStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = AVAudioSession.sharedInstance().recordPermission
    switch status {
    case .granted:
      completion(GrantWire.granted.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .undetermined:
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        ensureMainThread {
          completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapRecordStatus(_ status: AVAudioSession.RecordPermission) -> String {
    switch status {
    case .granted: return GrantWire.granted.rawValue
    case .undetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}
