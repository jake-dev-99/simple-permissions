import HealthKit

/// HealthKit authorization adapter. The existing registration uses
/// step count as a proxy object type — the underlying HealthKit
/// authorization model is per-object-type, but the Dart-facing
/// `HealthAccess` permission represents "can read steps" as a
/// stand-in for "has HealthKit permission at all." Callers that
/// need per-object-type gating should use
/// `PermissionGuards.authorizationStatus(for: .health(specificType))`
/// directly from their own Swift code.
///
/// The `.health(HKObjectType)` case on ApplePermissionKind already
/// handles the HealthKit-unavailable guard; this handler's
/// `isSupported` short-circuits the same check via the plugin's
/// isSupported gate so callers see `.notAvailable` there first.
final class HealthPermissionHandler: PermissionHandler {
  /// Fixed proxy type so the handler matches the legacy
  /// `HealthAccess`-as-step-count semantics.
  private static let proxyType: HKObjectType = {
    HKQuantityType.quantityType(forIdentifier: .stepCount)!
  }()

  var isSupported: Bool { HKHealthStore.isHealthDataAvailable() }

  func check(completion: @escaping (String) -> Void) {
    completion(
      PermissionGuards.authorizationStatus(for: .health(Self.proxyType)).rawValue
    )
  }

  func request(completion: @escaping (String) -> Void) {
    Task {
      let grant = await PermissionGuards
        .requestAuthorization(for: .health(Self.proxyType))
      ensureMainThread { completion(grant.rawValue) }
    }
  }
}
