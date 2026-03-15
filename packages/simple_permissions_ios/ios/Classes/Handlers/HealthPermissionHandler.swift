import HealthKit

final class HealthPermissionHandler: PermissionHandler {
  var isSupported: Bool { HKHealthStore.isHealthDataAvailable() }

  func check(completion: @escaping (String) -> Void) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }

    let store = HKHealthStore()
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    switch store.authorizationStatus(for: stepType) {
    case .sharingAuthorized:
      completion(GrantWire.granted.rawValue)
    case .sharingDenied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .notDetermined:
      completion(GrantWire.denied.rawValue)
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  func request(completion: @escaping (String) -> Void) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }

    let store = HKHealthStore()
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    store.requestAuthorization(toShare: [stepType], read: [stepType]) { success, _ in
      ensureMainThread {
        completion(success ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
      }
    }
  }
}
