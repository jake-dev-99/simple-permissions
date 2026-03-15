import Speech

final class SpeechPermissionHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    completion(mapSpeechStatus(SFSpeechRecognizer.authorizationStatus()))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = SFSpeechRecognizer.authorizationStatus()
    switch status {
    case .authorized:
      completion(GrantWire.granted.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      SFSpeechRecognizer.requestAuthorization { newStatus in
        ensureMainThread {
          completion(self.mapSpeechStatus(newStatus))
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapSpeechStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}
