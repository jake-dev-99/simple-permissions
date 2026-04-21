import AVFoundation
import Contacts
import CoreLocation
import EventKit
import Foundation
import Photos
import UserNotifications

// MARK: - MacOSPermissionKind

/// Identifies a macOS framework-level authorization the caller can
/// check or assert on.
///
/// The macOS analog of iOS's `ApplePermissionKind`. Kept as a
/// separate enum rather than a shared `ApplePermissionKind` because
/// macOS covers a smaller subset of frameworks and the two modules
/// don't share source today (matches the handler split already
/// tracked in `Classes/Handlers/SYNC.md`).
///
/// Explicitly NOT covered:
///
/// - `notifications` — lives on `isNotificationsAuthorized()` /
///   `requireNotificationsAuthorized()` because
///   `UNUserNotificationCenter.getNotificationSettings` is async-only.
/// - iOS-only kinds (bluetooth, speech, tracking, motion, health) —
///   those frameworks either don't exist on macOS or have different
///   access models.
public enum MacOSPermissionKind: String {
    case contacts
    case camera
    case microphone
    case calendar
    case reminders
    case photoLibrary           // read-write
    case photoLibraryAddOnly
    case location               // whenInUse OR always counts as authorized
}

// MARK: - PermissionDeniedError

/// Thrown by `PermissionGuards.require*` when a caller invokes a
/// permission-gated operation without holding the required
/// authorization. Sibling plugins catch this and surface a clear
/// domain error instead of the framework's opaque one.
///
/// macOS analog of iOS's `PermissionDeniedError`; the struct is
/// duplicated in each module (not shared) so sibling pods importing
/// only one platform's module still get the symbol.
public struct PermissionDeniedError: Error, CustomStringConvertible {
    public let deniedPermissions: [String]
    public let message: String

    public var description: String { message }
}

// MARK: - PermissionGuards

/// Native-side helpers for sibling Flutter plugins whose Swift code
/// calls authorization-gated macOS frameworks.
///
/// Mirrors the iOS module's API shape; see
/// `docs/INTEGRATION_GUIDE.md` for the three-layer responsibility
/// model. The TL;DR: sibling plugins annotate their Swift entry
/// points with `try PermissionGuards.requireAuthorized(for: .camera)`
/// and let the library-specific `PermissionDeniedError` propagate to
/// the caller.
public enum PermissionGuards {

    /// True iff [kind] is currently authorized for this app.
    ///
    /// Read-only — no UI, no request, no state change.
    public static func isAuthorized(for kind: MacOSPermissionKind) -> Bool {
        switch kind {
        case .contacts:
            return CNContactStore.authorizationStatus(for: .contacts) == .authorized

        case .camera:
            return AVCaptureDevice.authorizationStatus(for: .video) == .authorized

        case .microphone:
            // macOS uses AVCaptureDevice for microphone authorization —
            // AVAudioSession (iOS-only) isn't available here. Matches
            // the existing MicrophonePermissionHandler on macOS.
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

        case .calendar:
            return isEventKitAuthorized(for: .event)

        case .reminders:
            return isEventKitAuthorized(for: .reminder)

        case .photoLibrary:
            // PHPhotoLibrary.authorizationStatus(for:) is macOS 11+;
            // the parameterless class method is the 10.15 fallback,
            // matching the existing PhotoLibraryPermissionHandler.
            let status: PHAuthorizationStatus
            if #available(macOS 11.0, *) {
                status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            } else {
                status = PHPhotoLibrary.authorizationStatus()
            }
            return status == .authorized || status == .limited

        case .photoLibraryAddOnly:
            // .addOnly is only meaningful from macOS 11.0, where
            // PHAccessLevel exists. Pre-11 has no distinction between
            // read-write and add-only; treat as unauthorized under
            // 10.15 so callers either check .photoLibrary (which
            // subsumes add-only capability pre-11) or fall through.
            if #available(macOS 11.0, *) {
                return PHPhotoLibrary.authorizationStatus(for: .addOnly) == .authorized
            }
            return false

        case .location:
            // CLLocationManager().authorizationStatus (instance prop) is
            // macOS 11+; the class method CLLocationManager.authorizationStatus()
            // is the 10.15 fallback. Matches the dance in the existing
            // macOS LocationPermissionHandler.
            let status: CLAuthorizationStatus
            if #available(macOS 11.0, *) {
                status = CLLocationManager().authorizationStatus
            } else {
                status = CLLocationManager.authorizationStatus()
            }
            // macOS has authorizedAlways only (no WhenInUse equivalent)
            // plus a separate `.authorized` legacy value. Accept both.
            return status == .authorizedAlways || status == .authorized
        }
    }

    /// Throws [PermissionDeniedError] unless [kind] is authorized.
    public static func requireAuthorized(for kind: MacOSPermissionKind) throws {
        if isAuthorized(for: kind) { return }
        throw PermissionDeniedError(
            deniedPermissions: [kind.rawValue],
            message: "Operation requires \(kind.rawValue) but it is not authorized."
        )
    }

    /// Throws [PermissionDeniedError] unless at least one of [kinds]
    /// is authorized. Empty [kinds] always throws.
    public static func requireAnyAuthorized(for kinds: [MacOSPermissionKind]) throws {
        if kinds.contains(where: { isAuthorized(for: $0) }) { return }
        throw PermissionDeniedError(
            deniedPermissions: kinds.map(\.rawValue),
            message: kinds.isEmpty
                ? "Operation requires at least one authorization but none were specified."
                : "Operation requires one of \(kinds.map(\.rawValue)) but none are authorized."
        )
    }

    /// Throws [PermissionDeniedError] unless every one of [kinds] is
    /// authorized. `deniedPermissions` lists only the missing subset.
    /// Empty [kinds] is vacuously satisfied.
    public static func requireAllAuthorized(for kinds: [MacOSPermissionKind]) throws {
        let missing = kinds.filter { !isAuthorized(for: $0) }
        if missing.isEmpty { return }
        throw PermissionDeniedError(
            deniedPermissions: missing.map(\.rawValue),
            message: "Operation requires all of \(kinds.map(\.rawValue)) but missing: \(missing.map(\.rawValue))."
        )
    }

    // MARK: - Notifications (async)

    /// True iff the app currently holds notification authorization.
    /// Async because `getNotificationSettings` is callback-only on
    /// macOS too. Treats `.authorized` / `.provisional` / `.ephemeral`
    /// as authorized.
    public static func isNotificationsAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
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

    // MARK: - Private helpers

    /// EventKit splits `.authorized` and `.fullAccess` since macOS 14;
    /// both mean "can read". `.writeOnly` is explicitly NOT treated as
    /// authorized here — see the iOS analog for rationale.
    private static func isEventKitAuthorized(for entity: EKEntityType) -> Bool {
        let status = EKEventStore.authorizationStatus(for: entity)
        if #available(macOS 14.0, *) {
            return status == .authorized || status == .fullAccess
        }
        return status == .authorized
    }
}
