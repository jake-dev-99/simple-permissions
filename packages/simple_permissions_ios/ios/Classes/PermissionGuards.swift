import AVFoundation
import AppTrackingTransparency
import Contacts
import CoreBluetooth
import CoreLocation
import CoreMotion
import EventKit
import Foundation
import Photos
import Speech
import UserNotifications

// MARK: - ApplePermissionKind

/// Identifies an Apple framework-level authorization the caller can
/// check or assert on.
///
/// Mirrors the manifest-permission strings on Android. Each case
/// knows which framework API to call — sibling plugins don't import
/// Apple frameworks themselves to gate their own methods, they just
/// ask `PermissionGuards` by kind.
///
/// Explicitly NOT covered (documented in `docs/INTEGRATION_GUIDE.md`):
///
/// - `health` — `HKHealthStore.authorizationStatus(for:)` is
///   parameterized by `HKObjectType`; a single case can't carry
///   that. Sibling plugins needing HealthKit gating call the
///   framework directly with a domain wrapper.
/// - `notifications` — lives on `isNotificationsAuthorized()` /
///   `requireNotificationsAuthorized()` because
///   `UNUserNotificationCenter.getNotificationSettings` is async-only.
public enum ApplePermissionKind: String {
    case contacts
    case camera
    case microphone
    case calendar
    case reminders
    case photoLibrary           // read-write
    case photoLibraryAddOnly
    case location               // whenInUse OR always counts as authorized
    case speech
    case tracking               // iOS 14+
    case motion
    case bluetooth              // iOS 13+
}

// MARK: - PermissionDeniedError

/// Thrown by `PermissionGuards.require*` when a caller invokes a
/// permission-gated operation without holding the required
/// authorization. Sibling plugins catch this and surface a clear
/// domain error instead of the framework's opaque one.
///
/// The Apple analog of Kotlin's `PermissionDeniedException`.
public struct PermissionDeniedError: Error, CustomStringConvertible {
    /// The kind names (e.g. `"camera"`, `"microphone"`) that were
    /// required but not authorized. Order matches the collection
    /// passed to the helper; `requireAll` lists only missing items.
    public let deniedPermissions: [String]
    public let message: String

    public var description: String { message }
}

// MARK: - PermissionGuards

/// Native-side helpers for sibling Flutter plugins whose Swift code
/// calls authorization-gated Apple frameworks.
///
/// ### Two shapes
///
/// - `isAuthorized(for:)` — read-only boolean, equivalent to the
///   handlers' own "is granted" check. Use when the caller wants to
///   branch silently.
/// - `requireAuthorized(for:)` (and `requireAny*` / `requireAll*`) —
///   throws [`PermissionDeniedError`] on missing authorization.
///   Defense-in-depth for a sibling plugin's Swift entry point: call
///   at the top of a method about to invoke a framework API requiring
///   that authorization, so a caller who skipped the Dart-side
///   `ensureGranted` gets a clear domain error rather than the
///   framework's opaque one.
///
/// ### What this is NOT
///
/// - Not a request flow. Request still routes through the Dart API.
/// - Not a lint-equivalent. Apple has no `MissingPermission` lint;
///   the runtime assertion is the only signal. See
///   `docs/INTEGRATION_GUIDE.md`.
///
/// ### Thread safety
///
/// Every Apple `authorizationStatus`-family call documented here is
/// thread-safe and synchronous (per Apple's docs) except notifications,
/// which has its own async API below. Callers may invoke from any
/// queue. Internal delegates used for async requests still go through
/// the Dart API, not here.
public enum PermissionGuards {

    /// True iff [kind] is currently authorized for this app.
    ///
    /// Read-only — does not surface UI, does not trigger a request,
    /// does not touch authorization state.
    ///
    /// See [ApplePermissionKind] for the set of covered frameworks.
    /// Kinds not listed there (notifications, health) have dedicated
    /// helpers or are deferred — see the module docs.
    public static func isAuthorized(for kind: ApplePermissionKind) -> Bool {
        switch kind {
        case .contacts:
            return CNContactStore.authorizationStatus(for: .contacts) == .authorized

        case .camera:
            return AVCaptureDevice.authorizationStatus(for: .video) == .authorized

        case .microphone:
            // iOS-only microphone API — macOS uses AVCaptureDevice instead,
            // handled in the macOS module's PermissionGuards.
            return AVAudioSession.sharedInstance().recordPermission == .granted

        case .calendar:
            return isEventKitAuthorized(for: .event)

        case .reminders:
            return isEventKitAuthorized(for: .reminder)

        case .photoLibrary:
            // .limited still counts as "app can proceed" — matches
            // PermissionResult.isFullyGranted treating limited as
            // satisfied on the Dart side.
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            return status == .authorized || status == .limited

        case .photoLibraryAddOnly:
            return PHPhotoLibrary.authorizationStatus(for: .addOnly) == .authorized

        case .location:
            let status = CLLocationManager().authorizationStatus
            return status == .authorizedAlways || status == .authorizedWhenInUse

        case .speech:
            return SFSpeechRecognizer.authorizationStatus() == .authorized

        case .tracking:
            if #available(iOS 14.0, *) {
                return ATTrackingManager.trackingAuthorizationStatus == .authorized
            }
            // Pre-iOS-14: no tracking consent concept. Treat as
            // authorized — matches the notAvailable-as-implicit-grant
            // stance of the handler side for this case.
            return true

        case .motion:
            return CMMotionActivityManager.authorizationStatus() == .authorized

        case .bluetooth:
            if #available(iOS 13.0, *) {
                return CBManager.authorization == .allowedAlways
            }
            // Pre-iOS-13: no CB permission model. Treat as authorized.
            return true
        }
    }

    /// Throws [PermissionDeniedError] unless [kind] is authorized.
    public static func requireAuthorized(for kind: ApplePermissionKind) throws {
        if isAuthorized(for: kind) { return }
        throw PermissionDeniedError(
            deniedPermissions: [kind.rawValue],
            message: "Operation requires \(kind.rawValue) but it is not authorized."
        )
    }

    /// Throws [PermissionDeniedError] unless at least one of [kinds]
    /// is authorized. Use when the framework accepts any of several
    /// equivalent authorizations.
    ///
    /// An empty [kinds] collection always throws — a caller with no
    /// required authorization set has nothing to assert and almost
    /// certainly got there by mistake. Matches the Kotlin
    /// `requireAnyPermissionGranted` semantics.
    public static func requireAnyAuthorized(for kinds: [ApplePermissionKind]) throws {
        if kinds.contains(where: { isAuthorized(for: $0) }) { return }
        throw PermissionDeniedError(
            deniedPermissions: kinds.map(\.rawValue),
            message: kinds.isEmpty
                ? "Operation requires at least one authorization but none were specified."
                : "Operation requires one of \(kinds.map(\.rawValue)) but none are authorized."
        )
    }

    /// Throws [PermissionDeniedError] unless every one of [kinds] is
    /// authorized. The error's `deniedPermissions` lists only the
    /// missing subset, not the full required set — so callers can
    /// surface precise error UI.
    ///
    /// Empty [kinds] is vacuously satisfied. Matches Kotlin
    /// `requireAllPermissionsGranted` semantics.
    public static func requireAllAuthorized(for kinds: [ApplePermissionKind]) throws {
        let missing = kinds.filter { !isAuthorized(for: $0) }
        if missing.isEmpty { return }
        throw PermissionDeniedError(
            deniedPermissions: missing.map(\.rawValue),
            message: "Operation requires all of \(kinds.map(\.rawValue)) but missing: \(missing.map(\.rawValue))."
        )
    }

    // MARK: - Notifications (async)

    /// True iff the app currently holds notification authorization.
    ///
    /// Async because `UNUserNotificationCenter.getNotificationSettings`
    /// is callback-only — there is no synchronous API to query
    /// notification settings on iOS.
    ///
    /// Treats `.authorized`, `.provisional`, and `.ephemeral` as
    /// authorized (matches the notification handler's mapping,
    /// matches `PermissionGrantStatus.isSatisfied` on the Dart side —
    /// provisional delivers quietly but the operation proceeds).
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

    /// EventKit exposes two overlapping "authorized" states since
    /// iOS 17: `.authorized` (legacy) and `.fullAccess` (iOS 17+
    /// granular model). Both mean "the app can read events"; collapse
    /// them here so the guard is version-insensitive.
    ///
    /// `.writeOnly` (iOS 17+) is explicitly NOT treated as authorized —
    /// write-only access isn't enough to satisfy a read-requiring
    /// caller. Sibling plugins that need write-only semantics should
    /// use `isAuthorized(for:)` and branch themselves.
    private static func isEventKitAuthorized(for entity: EKEntityType) -> Bool {
        let status = EKEventStore.authorizationStatus(for: entity)
        if #available(iOS 17.0, *) {
            return status == .authorized || status == .fullAccess
        }
        return status == .authorized
    }
}
