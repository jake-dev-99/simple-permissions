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
/// check, assert on, or request via [PermissionGuards].
///
/// Each case knows which framework API to call. The enum is the
/// "vocabulary owner" — callers don't import AVFoundation, Contacts,
/// etc. to query authorization; they ask PermissionGuards by kind.
///
/// Explicitly not covered:
///
/// - `notifications` — lives on [PermissionGuards.isNotificationsAuthorized] /
///   [PermissionGuards.requireNotificationsAuthorized] /
///   [PermissionGuards.requestNotificationsAuthorization] because
///   `UNUserNotificationCenter.getNotificationSettings` is async-only.
/// - `health` — an HealthKit authorization lookup is parameterized by
///   an `HKObjectType`. Added in 1.8.0; see `.health(_:)`.
public enum ApplePermissionKind {
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

    /// Stable string identifier used in error messages and
    /// `PermissionDeniedError.deniedPermissions`. Stays equivalent to
    /// the pre-1.8 `String`-backed rawValue for each case so log scrapers
    /// and error-equality checks continue to work.
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
        case .speech:              return "speech"
        case .tracking:            return "tracking"
        case .motion:              return "motion"
        case .bluetooth:           return "bluetooth"
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
/// Raw-string values match the Dart wire format ("granted", "denied",
/// …) so they serialize 1:1 across the Pigeon boundary used elsewhere
/// in the plugin.
public enum PermissionGrant: String {
    /// The user (or OS) has granted the permission.
    case granted

    /// The user denied the request but can be asked again.
    case denied

    /// The user chose "Don't allow" and further requests surface no
    /// prompt. On Apple, this is the `.denied` state of most auth
    /// enums; the operation needs the user to change the value in
    /// Settings manually.
    case permanentlyDenied

    /// The OS restricts this permission (e.g. Parental Controls) and
    /// the user cannot grant it.
    case restricted

    /// Partial access (e.g. iOS limited-photo-library selection, or
    /// EventKit write-only). Caller should proceed but may see a
    /// reduced data surface.
    case limited

    /// This kind doesn't exist as a concept on the current platform.
    /// The caller should branch its feature off rather than prompt.
    case notApplicable

    /// This kind exists on the platform but not on the running OS
    /// version (e.g. `tracking` pre-iOS-14, `bluetooth` pre-iOS-13).
    case notAvailable

    /// iOS provisional notification authorization (delivers quietly).
    /// Notifications-only; other kinds never return this.
    case provisional
}

extension PermissionGrant {
    /// The operation gated by this grant may proceed.
    ///
    /// `.limited` and `.provisional` count as satisfied — both still
    /// let the core framework call succeed, just with a reduced
    /// surface (limited photo selection, quiet notifications). Matches
    /// the Dart-side `PermissionGrantStatus.isSatisfied` predicate.
    public var isSatisfied: Bool {
        self == .granted || self == .limited || self == .provisional
    }

    /// The user (or OS) has refused the permission in some form.
    /// Mutually exclusive with [isSatisfied] and [isUnsupported].
    public var isDenied: Bool {
        self == .denied || self == .permanentlyDenied || self == .restricted
    }

    /// This permission cannot be exercised on this platform / OS
    /// version. No user action changes this state.
    public var isUnsupported: Bool {
        self == .notApplicable || self == .notAvailable
    }

    /// Re-requesting this permission is a no-op — either the OS
    /// refuses to prompt (permanentlyDenied, restricted) or the
    /// concept doesn't exist (notApplicable, notAvailable).
    public var isTerminal: Bool {
        self == .permanentlyDenied || self == .restricted
            || self == .notApplicable || self == .notAvailable
    }
}

// MARK: - PermissionDeniedError

/// Thrown by [PermissionGuards] `require*` helpers when a caller
/// invokes a permission-gated operation without holding the required
/// authorization.
///
/// Extends `Error` so callers that already handle framework
/// authorization errors can `catch` this at the same surface.
/// `deniedPermissions` names the kinds that were missing so the caller
/// can surface precise error UI.
public struct PermissionDeniedError: Error, CustomStringConvertible {
    /// Kind identifiers (e.g. `"camera"`, `"microphone"`) that were
    /// required but not authorized. Order matches the collection
    /// passed to the helper; `requireAll` lists only missing items.
    public let deniedPermissions: [String]
    public let message: String

    public var description: String { message }
}

// MARK: - PermissionGuards

/// A Swift helper for iOS / macOS app code that needs to check,
/// assert, or request Apple authorization state without reaching for
/// each framework's own auth API directly.
///
/// ### Three shapes
///
/// - [authorizationStatus(for:)] — returns the full [PermissionGrant]
///   (8-state) so the caller can distinguish denied vs permanently
///   denied vs restricted vs limited vs not-available.
/// - [isAuthorized(for:)] — boolean shortcut equivalent to
///   `authorizationStatus(for: kind).isSatisfied`. Use when the caller
///   just wants to branch on "proceed or don't."
/// - [requireAuthorized(for:)] / [requireAnyAuthorized(for:)] /
///   [requireAllAuthorized(for:)] — throw [PermissionDeniedError] on
///   missing authorization. Use at the top of a method about to invoke
///   a framework API requiring that authorization, so callers who
///   skipped the check get a clear domain error rather than the
///   framework's opaque one.
/// - [requestAuthorization(for:)] / [requireAuthorizationGranted(for:)] —
///   async. Trigger the native prompt (on first use) and return the
///   post-prompt grant.
///
/// ### Thread safety
///
/// Every synchronous Apple `authorizationStatus`-family call used here
/// is thread-safe per Apple's docs. The async request flows dispatch
/// their completions on the main queue where Apple requires it.
public enum PermissionGuards {

    // MARK: Status

    /// Full multi-state grant for [kind]. Read-only — no UI, no
    /// request, no state change.
    ///
    /// See [PermissionGrant] for what each state means. For kinds
    /// that don't exist on the running OS version (e.g. `.tracking`
    /// pre-iOS-14, `.bluetooth` pre-iOS-13), returns
    /// `.notAvailable` rather than claiming `.granted` —
    /// differentiates from "supported and authorized."
    public static func authorizationStatus(for kind: ApplePermissionKind) -> PermissionGrant {
        switch kind {
        case .contacts:            return contactsStatus()
        case .camera:              return avCaptureStatus(for: .video)
        case .microphone:          return microphoneStatus()
        case .calendar:            return eventKitStatus(for: .event)
        case .reminders:           return eventKitStatus(for: .reminder)
        case .photoLibrary:        return photoLibraryStatus(for: .readWrite)
        case .photoLibraryAddOnly: return photoLibraryStatus(for: .addOnly)
        case .location:            return locationStatus()
        case .speech:              return speechStatus()
        case .tracking:            return trackingStatus()
        case .motion:              return motionStatus()
        case .bluetooth:           return bluetoothStatus()
        }
    }

    /// True iff [kind] is in a satisfied state (granted / limited /
    /// provisional). Equivalent to
    /// `authorizationStatus(for: kind).isSatisfied`.
    public static func isAuthorized(for kind: ApplePermissionKind) -> Bool {
        return authorizationStatus(for: kind).isSatisfied
    }

    // MARK: Require

    /// Throws [PermissionDeniedError] unless [kind] is authorized.
    public static func requireAuthorized(for kind: ApplePermissionKind) throws {
        if isAuthorized(for: kind) { return }
        throw PermissionDeniedError(
            deniedPermissions: [kind.identifier],
            message: "Operation requires \(kind.identifier) but it is not authorized."
        )
    }

    /// Throws [PermissionDeniedError] unless at least one of [kinds]
    /// is authorized. Use when the framework accepts any of several
    /// equivalent authorizations.
    ///
    /// An empty [kinds] collection always throws — a caller with no
    /// required authorization set has nothing to assert and almost
    /// certainly got there by mistake.
    public static func requireAnyAuthorized(for kinds: [ApplePermissionKind]) throws {
        if kinds.contains(where: { isAuthorized(for: $0) }) { return }
        throw PermissionDeniedError(
            deniedPermissions: kinds.map(\.identifier),
            message: kinds.isEmpty
                ? "Operation requires at least one authorization but none were specified."
                : "Operation requires one of \(kinds.map(\.identifier)) but none are authorized."
        )
    }

    /// Throws [PermissionDeniedError] unless every one of [kinds] is
    /// authorized. The error's `deniedPermissions` lists only the
    /// missing subset, not the full required set — so callers can
    /// surface precise error UI.
    ///
    /// Empty [kinds] is vacuously satisfied.
    public static func requireAllAuthorized(for kinds: [ApplePermissionKind]) throws {
        let missing = kinds.filter { !isAuthorized(for: $0) }
        if missing.isEmpty { return }
        throw PermissionDeniedError(
            deniedPermissions: missing.map(\.identifier),
            message: "Operation requires all of \(kinds.map(\.identifier)) but missing: \(missing.map(\.identifier))."
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
    /// authorized — matches [PermissionGrant.isSatisfied] on the
    /// Dart side where provisional delivers quietly but the operation
    /// proceeds.
    public static func isNotificationsAuthorized() async -> Bool {
        return await notificationsStatus().isSatisfied
    }

    /// Full [PermissionGrant] for notifications. Async for the same
    /// reason as [isNotificationsAuthorized]; returns `.provisional`
    /// for iOS provisional / ephemeral (both deliver quietly and
    /// satisfy the gate).
    public static func notificationsStatus() async -> PermissionGrant {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:        return .granted
        case .provisional:       return .provisional
        case .ephemeral:         return .provisional
        case .denied:            return .permanentlyDenied
        case .notDetermined:     return .denied
        @unknown default:        return .denied
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
        // iOS 18+ added `.limited` as a first-class case. Surface as
        // limited so callers treating partial access as satisfied
        // (matches photo-library semantics + Dart-side
        // PermissionGrant.isSatisfied) don't have to special-case it.
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

    private static func microphoneStatus() -> PermissionGrant {
        // iOS-only microphone API via AVAudioSession. macOS routes
        // through AVCaptureDevice(.audio) instead (handled in the
        // macOS module's PermissionGuards).
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:     return .granted
        case .denied:      return .permanentlyDenied
        case .undetermined: return .denied
        @unknown default:  return .denied
        }
    }

    private static func eventKitStatus(for entity: EKEntityType) -> PermissionGrant {
        // EKAuthorizationStatus.fullAccess / .writeOnly are iOS 17+,
        // but the enum cases exist in the current SDK regardless of
        // deployment target — on pre-17 devices they simply never
        // surface at runtime. Swift needs them in the switch either
        // way; the runtime branch takes care of itself.
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

    private static func photoLibraryStatus(for level: PHAccessLevel) -> PermissionGrant {
        switch PHPhotoLibrary.authorizationStatus(for: level) {
        case .authorized:    return .granted
        case .limited:       return .limited
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }

    private static func locationStatus() -> PermissionGrant {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways:
            return .granted
        case .authorizedWhenInUse:
            // whenInUse is a reduced authorization vs always, but for
            // the common "can I use location at all" question it's
            // satisfying. Report as granted. Callers that need to
            // distinguish always-vs-whenInUse should read the
            // CLLocationManager directly.
            return .granted
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }

    private static func speechStatus() -> PermissionGrant {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:    return .granted
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }

    private static func trackingStatus() -> PermissionGrant {
        if #available(iOS 14.0, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .authorized:    return .granted
            case .denied:        return .permanentlyDenied
            case .restricted:    return .restricted
            case .notDetermined: return .denied
            @unknown default:    return .denied
            }
        }
        // Pre-iOS-14: no tracking consent concept. Report
        // notAvailable — the operation is unauthorized-by-construction
        // rather than implicitly granted, so callers don't accidentally
        // treat missing-concept as permission-held.
        return .notAvailable
    }

    private static func motionStatus() -> PermissionGrant {
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:    return .granted
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }

    private static func bluetoothStatus() -> PermissionGrant {
        if #available(iOS 13.0, *) {
            switch CBManager.authorization {
            case .allowedAlways: return .granted
            case .denied:        return .permanentlyDenied
            case .restricted:    return .restricted
            case .notDetermined: return .denied
            @unknown default:    return .denied
            }
        }
        // Pre-iOS-13: no CB permission model. Report notAvailable.
        return .notAvailable
    }
}
