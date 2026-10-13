import EventKit

/// Calendar / reminders authorization adapter. Parameterized on
/// `EKEntityType` at construction so one class serves both the
/// calendar (`event`) and reminders (`reminder`) registrations —
/// the entity type maps 1:1 to the matching `ApplePermissionKind`.
final class CalendarPermissionHandler: PermissionHandler {
  let entityType: EKEntityType

  init(entityType: EKEntityType) {
    self.entityType = entityType
  }

  var isSupported: Bool { true }

  /// The `ApplePermissionKind` for this handler's entity type.
  /// `.event` → `.calendar`, `.reminder` → `.reminders`. Any future
  /// entity type would need a matching kind added here; until then
  /// fall back to `.calendar` which mirrors the pre-1.8 handler
  /// behavior for unknown entity types.
  private var kind: ApplePermissionKind {
    switch entityType {
    case .event:    return .calendar
    case .reminder: return .reminders
    @unknown default: return .calendar
    }
  }

  func check(completion: @escaping (String) -> Void) {
    completion(PermissionGuards.authorizationStatus(for: kind).rawValue)
  }

  func request(completion: @escaping (String) -> Void) {
    let kind = self.kind
    Task {
      let grant = await PermissionGuards.requestAuthorization(for: kind)
      ensureMainThread { completion(grant.rawValue) }
    }
  }
}
