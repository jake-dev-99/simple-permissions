import AVFoundation
import Contacts
import CoreLocation
import EventKit
import Foundation
import Photos
import UserNotifications

// MARK: - MacOSPermissionKind

/// Identifies a macOS framework-level authorization the caller can
/// check, assert on, or request via [PermissionGuards].
///
/// The macOS analog of iOS's `ApplePermissionKind`. Kept as a separate
/// enum rather than a shared type because macOS covers a smaller
/// subset of frameworks (no bluetooth, speech, tracking, motion, or
/// health — those don't exist on macOS or have different access
/// models). The two modules don't share source today; the handler
/// split already tracked in `Classes/Handlers/SYNC.md` follows the
/// same pattern.
///
/// Explicitly not covered:
///
/// - `notifications` — lives on the async
///   [PermissionGuards.isNotificationsAuthorized] /
///   [PermissionGuards.requireNotificationsAuthorized] /
///   [PermissionGuards.requestNotificationsAuthorization] because
///   `UNUserNotificationCenter.getNotificationSettings` is async-only.
public enum MacOSPermissionKind {
    case contacts
    case camera
    case microphone
    case calendar
    case reminders
    case photoLibrary           // read-write
    case photoLibraryAddOnly
    case location               // authorizedAlways OR authorized legacy

    /// Stable string identifier used in error messages and
    /// `PermissionDeniedError.deniedPermissions`. Matches the
    /// pre-1.8 `String`-backed rawValue so log scrapers continue to
    /// work.
    public var identifier: String {
        switch self {
        case .contacts:            return "contacts"
        case .camera:              return "camera"
        case .microphone:          return "microphone"
        case .calendar:            return "calendar"
        case .reminders:           return "reminders"
        case .photoLibrary:        return "photoLibrary"
        case .photoLibraryAddOnly: return "photoLibraryAddOnly"
        case .location:            return "location"
        }
    }
}

// MARK: - PermissionGrant

/// Swift mirror of Dart's `PermissionGrant` enum (eight cases,
/// `PermissionGrantStatus` predicates). Exposed so caller code can
/// branch on denial mode — `permanentlyDenied` routes to Settings,
/// plain `denied` is re-requestable, `restricted` surfaces a parental-
/// controls message, and so on — instead of flattening everything
/// into `Bool`.
///
/// Raw-string values match the Dart wire format so they serialize
/// 1:1 across the Pigeon boundary used elsewhere in the plugin.
///
/// Duplicated in each platform module (iOS, macOS) rather than
/// shared, so sibling pods importing only one platform's module
/// still get the symbol.
public enum PermissionGrant: String {
    case granted
    case denied
    case permanentlyDenied
    case restricted
    case limited
    case notApplicable
    case notAvailable
    case provisional
}

extension PermissionGrant {
    /// The operation gated by this grant may proceed.
    public var isSatisfied: Bool {
        self == .granted || self == .limited || self == .provisional
    }

    /// The user (or OS) has refused the permission in some form.
    public var isDenied: Bool {
        self == .denied || self == .permanentlyDenied || self == .restricted
    }

    /// This permission cannot be exercised on this platform / OS version.
    public var isUnsupported: Bool {
        self == .notApplicable || self == .notAvailable
    }

    /// Re-requesting is a no-op.
    public var isTerminal: Bool {
        self == .permanentlyDenied || self == .restricted
            || self == .notApplicable || self == .notAvailable
    }
}

// MARK: - PermissionDeniedError

/// Thrown by [PermissionGuards] `require*` helpers when a caller
/// invokes a permission-gated operation without holding the required
/// authorization.
public struct PermissionDeniedError: Error, CustomStringConvertible {
    public let deniedPermissions: [String]
    public let message: String

    public var description: String { message }
}

// MARK: - PermissionGuards

/// A Swift helper for macOS app code that needs to check, assert, or
/// request Apple authorization state without reaching for each
/// framework's own auth API directly.
///
/// Mirrors the iOS module's API. See `docs/INTEGRATION_GUIDE.md` for
/// the full usage walkthrough.
public enum PermissionGuards {

    // MARK: Status

    /// Full multi-state grant for [kind]. Read-only — no UI, no
    /// request, no state change.
    public static func authorizationStatus(for kind: MacOSPermissionKind) -> PermissionGrant {
        switch kind {
        case .contacts:            return contactsStatus()
        case .camera:              return avCaptureStatus(for: .video)
        case .microphone:          return avCaptureStatus(for: .audio)
        case .calendar:            return eventKitStatus(for: .event)
        case .reminders:           return eventKitStatus(for: .reminder)
        case .photoLibrary:        return photoLibraryStatus(addOnly: false)
        case .photoLibraryAddOnly: return photoLibraryStatus(addOnly: true)
        case .location:            return locationStatus()
        }
    }

    /// True iff [kind] is in a satisfied state. Equivalent to
    /// `authorizationStatus(for: kind).isSatisfied`.
    public static func isAuthorized(for kind: MacOSPermissionKind) -> Bool {
        return authorizationStatus(for: kind).isSatisfied
    }

    // MARK: Require

    /// Throws [PermissionDeniedError] unless [kind] is authorized.
    public static func requireAuthorized(for kind: MacOSPermissionKind) throws {
        if isAuthorized(for: kind) { return }
        throw PermissionDeniedError(
            deniedPermissions: [kind.identifier],
            message: "Operation requires \(kind.identifier) but it is not authorized."
        )
    }

    /// Throws [PermissionDeniedError] unless at least one of [kinds]
    /// is authorized. Empty [kinds] always throws.
    public static func requireAnyAuthorized(for kinds: [MacOSPermissionKind]) throws {
        if kinds.contains(where: { isAuthorized(for: $0) }) { return }
        throw PermissionDeniedError(
            deniedPermissions: kinds.map(\.identifier),
            message: kinds.isEmpty
                ? "Operation requires at least one authorization but none were specified."
                : "Operation requires one of \(kinds.map(\.identifier)) but none are authorized."
        )
    }

    /// Throws [PermissionDeniedError] unless every one of [kinds] is
    /// authorized. Error's `deniedPermissions` lists only missing.
    /// Empty [kinds] is vacuously satisfied.
    public static func requireAllAuthorized(for kinds: [MacOSPermissionKind]) throws {
        let missing = kinds.filter { !isAuthorized(for: $0) }
        if missing.isEmpty { return }
        throw PermissionDeniedError(
            deniedPermissions: missing.map(\.identifier),
            message: "Operation requires all of \(kinds.map(\.identifier)) but missing: \(missing.map(\.identifier))."
        )
    }

    // MARK: - Notifications (async)

    /// True iff the app currently holds notification authorization.
    /// Async because `getNotificationSettings` is callback-only.
    public static func isNotificationsAuthorized() async -> Bool {
        return await notificationsStatus().isSatisfied
    }

    /// Full [PermissionGrant] for notifications. Async.
    public static func notificationsStatus() async -> PermissionGrant {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:    return .granted
        case .provisional:   return .provisional
        case .ephemeral:     return .provisional
        case .denied:        return .permanentlyDenied
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }

    /// Throws [PermissionDeniedError] unless notifications are
    /// authorized. Async counterpart to [requireAuthorized(for:)].
    public static func requireNotificationsAuthorized() async throws {
        if await isNotificationsAuthorized() { return }
        throw PermissionDeniedError(
            deniedPermissions: ["notifications"],
            message: "Operation requires notifications authorization but it is not granted."
        )
    }

    // MARK: - Private per-framework status helpers

    private static func contactsStatus() -> PermissionGrant {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:    return .granted
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        // macOS 15 added .limited; match photo-library semantics.
        case .limited:       return .limited
        @unknown default:    return .denied
        }
    }

    private static func avCaptureStatus(for type: AVMediaType) -> PermissionGrant {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized:    return .granted
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }

    private static func eventKitStatus(for entity: EKEntityType) -> PermissionGrant {
        // EKAuthorizationStatus.fullAccess / .writeOnly are macOS 14+,
        // but the cases exist in the current SDK. On pre-14 they
        // never surface at runtime; Swift needs them in the switch
        // either way.
        switch EKEventStore.authorizationStatus(for: entity) {
        case .authorized:    return .granted
        case .fullAccess:    return .granted
        case .writeOnly:     return .limited
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }

    private static func photoLibraryStatus(addOnly: Bool) -> PermissionGrant {
        // PHPhotoLibrary.authorizationStatus(for:) is macOS 11+. On
        // 10.15 there's no access-level concept — fall back to the
        // parameterless class method for read-write, and report
        // notApplicable for add-only (the distinction doesn't exist).
        if #available(macOS 11.0, *) {
            let level: PHAccessLevel = addOnly ? .addOnly : .readWrite
            switch PHPhotoLibrary.authorizationStatus(for: level) {
            case .authorized:    return .granted
            case .limited:       return .limited
            case .denied:        return .permanentlyDenied
            case .restricted:    return .restricted
            case .notDetermined: return .denied
            @unknown default:    return .denied
            }
        }
        if addOnly { return .notApplicable }
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:    return .granted
        case .limited:       return .limited
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }

    private static func locationStatus() -> PermissionGrant {
        // Instance-property accessor is macOS 11+; class method is
        // the 10.15 fallback. macOS has no WhenInUse equivalent —
        // authorizedAlways or the legacy `.authorized` both count.
        let status: CLAuthorizationStatus
        if #available(macOS 11.0, *) {
            status = CLLocationManager().authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        switch status {
        case .authorizedAlways:
            return .granted
        case .authorized:
            // Legacy macOS case used before authorizedAlways replaced
            // it; still surfaced by the SDK. Treat as granted.
            return .granted
        case .authorizedWhenInUse:
            // Compiler requires this case even though macOS doesn't
            // return it in practice. Treat as granted to match iOS
            // semantics so any runtime surprise stays permissive.
            return .granted
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }
}
