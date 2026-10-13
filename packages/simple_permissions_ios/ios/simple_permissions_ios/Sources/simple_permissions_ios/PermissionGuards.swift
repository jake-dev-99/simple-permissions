import AVFoundation
import AppTrackingTransparency
import Contacts
import CoreBluetooth
import CoreLocation
import CoreMotion
import EventKit
import Foundation
import HealthKit
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

    /// HealthKit authorization for a specific [HKObjectType] (e.g.
    /// `HKObjectType.quantityType(forIdentifier: .stepCount)`).
    ///
    /// **Important — Apple's privacy model**: `HKHealthStore.authorizationStatus(for:)`
    /// only reports **write** authorization. Read authorization is
    /// opaque by design (Apple prevents apps from inferring
    /// "user has no data" from "app has no read access"). So
    /// `isAuthorized(for: .health(type))` returning true means "can
    /// write," not "can read." Callers needing read-gated flows
    /// should attempt the fetch and handle empty/error results
    /// rather than pre-check.
    ///
    /// The request path (`requestAuthorization(for: .health(type))`)
    /// does ask the user for both share and read (where the type
    /// supports it), so the prompt surfaces correctly.
    case health(HKObjectType)

    /// Stable string identifier used in error messages and
    /// `PermissionDeniedError.deniedPermissions`. For `.health(_:)`,
    /// uses `"health:<identifier>"` where `<identifier>` is the
    /// HKObjectType's identifier string, so error messages can
    /// distinguish which specific health type failed.
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
        case .health(let type):    return "health:\(type.identifier)"
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
        case .contacts:             return contactsStatus()
        case .camera:               return avCaptureStatus(for: .video)
        case .microphone:           return microphoneStatus()
        case .calendar:             return eventKitStatus(for: .event)
        case .reminders:            return eventKitStatus(for: .reminder)
        case .photoLibrary:         return photoLibraryStatus(for: .readWrite)
        case .photoLibraryAddOnly:  return photoLibraryStatus(for: .addOnly)
        case .location:             return locationStatus()
        case .speech:               return speechStatus()
        case .tracking:             return trackingStatus()
        case .motion:               return motionStatus()
        case .bluetooth:            return bluetoothStatus()
        case .health(let type):     return healthStatus(for: type)
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

    // MARK: Request (async)

    /// Request authorization for [kind], returning the post-prompt
    /// grant. Short-circuits without prompting when the current
    /// grant is already satisfied or in a terminal state
    /// (permanentlyDenied / restricted / notApplicable / notAvailable)
    /// — matches the Dart-side `ensureGranted` semantics.
    ///
    /// May surface a system prompt the first time it's called for a
    /// kind whose current state is `.denied` (Apple `.notDetermined`).
    /// Subsequent calls with the same kind won't re-prompt — Apple's
    /// frameworks only surface the dialog on the first request.
    ///
    /// Callers that want to distinguish "granted" vs "user denied"
    /// vs "OS restricted" inspect the returned [PermissionGrant].
    /// Callers that want a throw-on-denial control flow use
    /// [requireAuthorizationGranted(for:)].
    public static func requestAuthorization(
        for kind: ApplePermissionKind
    ) async -> PermissionGrant {
        let current = authorizationStatus(for: kind)
        // isSatisfied covers granted/limited/provisional — already
        // usable. isTerminal covers permanentlyDenied/restricted/
        // notApplicable/notAvailable — prompt is a no-op. Only the
        // remaining state (.denied, meaning Apple's .notDetermined)
        // triggers a real prompt.
        if current.isSatisfied || current.isTerminal {
            return current
        }
        return await performRequest(for: kind)
    }

    /// Request authorization for [kind] and throw
    /// [PermissionDeniedError] unless the post-prompt grant is
    /// satisfied. Async counterpart to [requireAuthorized(for:)].
    ///
    /// Use at the top of a function about to invoke a framework API
    /// requiring authorization, when the caller wants the library to
    /// prompt if needed and fail loudly otherwise.
    public static func requireAuthorizationGranted(
        for kind: ApplePermissionKind
    ) async throws {
        let grant = await requestAuthorization(for: kind)
        if grant.isSatisfied { return }
        throw PermissionDeniedError(
            deniedPermissions: [kind.identifier],
            message: "Operation requires \(kind.identifier) but authorization was not granted (\(grant.rawValue))."
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

    /// Request notifications authorization, returning the post-prompt
    /// grant. Short-circuits without prompting when already decided.
    ///
    /// [options] controls which delivery capabilities are requested;
    /// defaults to alert+badge+sound which is the 99% case.
    /// `.provisional` and `.ephemeral` grants surface as
    /// [PermissionGrant.provisional].
    public static func requestNotificationsAuthorization(
        options: UNAuthorizationOptions = [.alert, .badge, .sound]
    ) async -> PermissionGrant {
        let current = await notificationsStatus()
        if current.isSatisfied || current.isTerminal {
            return current
        }
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: options)
            if granted { return .granted }
            return await notificationsStatus()
        } catch {
            return await notificationsStatus()
        }
    }

    /// Request notifications authorization and throw
    /// [PermissionDeniedError] unless the post-prompt grant is
    /// satisfied. Async counterpart to
    /// [requireAuthorizationGranted(for:)] for the notifications
    /// channel.
    public static func requireNotificationsAuthorizationGranted(
        options: UNAuthorizationOptions = [.alert, .badge, .sound]
    ) async throws {
        let grant = await requestNotificationsAuthorization(options: options)
        if grant.isSatisfied { return }
        throw PermissionDeniedError(
            deniedPermissions: ["notifications"],
            message: "Operation requires notifications authorization but it was not granted (\(grant.rawValue))."
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

    private static func healthStatus(for type: HKObjectType) -> PermissionGrant {
        // Not every iOS device has HealthKit (iPad historically
        // didn't). Report notAvailable so callers disable their
        // health-gated features rather than treating notAvailable as
        // a prompt opportunity.
        guard HKHealthStore.isHealthDataAvailable() else { return .notAvailable }
        // Apple's privacy model: this status only reflects WRITE
        // authorization. Read is opaque. See the doc comment on
        // `.health(_:)`.
        switch HKHealthStore().authorizationStatus(for: type) {
        case .notDetermined:     return .denied
        case .sharingDenied:     return .permanentlyDenied
        case .sharingAuthorized: return .granted
        @unknown default:        return .denied
        }
    }

    // MARK: - Private per-framework request helpers

    /// Dispatches to the kind-specific request helper after
    /// [requestAuthorization(for:)] confirmed a prompt is warranted.
    private static func performRequest(
        for kind: ApplePermissionKind
    ) async -> PermissionGrant {
        switch kind {
        case .contacts:             return await requestContacts()
        case .camera:               return await requestAVCapture(for: .video)
        case .microphone:           return await requestMicrophone()
        case .calendar:             return await requestEventKit(for: .event)
        case .reminders:            return await requestEventKit(for: .reminder)
        case .photoLibrary:         return await requestPhotoLibrary(for: .readWrite)
        case .photoLibraryAddOnly:  return await requestPhotoLibrary(for: .addOnly)
        case .location:             return await requestLocation()
        case .speech:               return await requestSpeech()
        case .tracking:             return await requestTracking()
        case .motion:               return await requestMotion()
        case .bluetooth:            return await requestBluetooth()
        case .health(let type):     return await requestHealth(type: type)
        }
    }

    private static func requestContacts() async -> PermissionGrant {
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                cont.resume(returning: granted)
            }
        }
        // Re-read status so limited / restricted are classified
        // correctly; requestAccess's `granted` Bool collapses
        // those into false.
        return granted ? .granted : contactsStatus()
    }

    private static func requestAVCapture(for type: AVMediaType) async -> PermissionGrant {
        let granted = await AVCaptureDevice.requestAccess(for: type)
        return granted ? .granted : avCaptureStatus(for: type)
    }

    private static func requestMicrophone() async -> PermissionGrant {
        // iOS 17 renamed the API to AVAudioApplication.
        // requestRecordPermission(); pre-17 still uses the
        // deprecated-in-17 AVAudioSession call. Route through
        // #available so both compile cleanly.
        if #available(iOS 17.0, *) {
            let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
            return granted ? .granted : microphoneStatus()
        } else {
            let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
            return granted ? .granted : microphoneStatus()
        }
    }

    private static func requestEventKit(for entity: EKEntityType) async -> PermissionGrant {
        let store = EKEventStore()
        if #available(iOS 17.0, *) {
            do {
                let granted: Bool
                switch entity {
                case .event:
                    granted = try await store.requestFullAccessToEvents()
                case .reminder:
                    granted = try await store.requestFullAccessToReminders()
                @unknown default:
                    granted = false
                }
                return granted ? .granted : eventKitStatus(for: entity)
            } catch {
                return eventKitStatus(for: entity)
            }
        }
        // Pre-iOS-17 — requestAccess is deprecated from 17 on but
        // is the only path on 14-16. Wrap in continuation.
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            store.requestAccess(to: entity) { granted, _ in
                cont.resume(returning: granted)
            }
        }
        return granted ? .granted : eventKitStatus(for: entity)
    }

    private static func requestPhotoLibrary(for level: PHAccessLevel) async -> PermissionGrant {
        let status = await PHPhotoLibrary.requestAuthorization(for: level)
        switch status {
        case .authorized:    return .granted
        case .limited:       return .limited
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }

    private static func requestLocation() async -> PermissionGrant {
        // CLLocationManager doesn't have an async request API — the
        // result arrives via delegate callback on a separate call.
        // Use a one-shot delegate wrapped in a continuation.
        return await _LocationAuthorizationCoordinator.requestWhenInUse()
    }

    private static func requestSpeech() async -> PermissionGrant {
        return await withCheckedContinuation { (cont: CheckedContinuation<PermissionGrant, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                let grant: PermissionGrant
                switch status {
                case .authorized:    grant = .granted
                case .denied:        grant = .permanentlyDenied
                case .restricted:    grant = .restricted
                case .notDetermined: grant = .denied
                @unknown default:    grant = .denied
                }
                cont.resume(returning: grant)
            }
        }
    }

    private static func requestTracking() async -> PermissionGrant {
        guard #available(iOS 14.0, *) else { return .notAvailable }
        let status = await ATTrackingManager.requestTrackingAuthorization()
        switch status {
        case .authorized:    return .granted
        case .denied:        return .permanentlyDenied
        case .restricted:    return .restricted
        case .notDetermined: return .denied
        @unknown default:    return .denied
        }
    }

    private static func requestMotion() async -> PermissionGrant {
        // CMMotionActivityManager has no explicit request API. The
        // permission prompt fires the first time you call
        // queryActivityStarting(...). After the user responds,
        // authorizationStatus() reflects the final state.
        let manager = CMMotionActivityManager()
        let queue = OperationQueue.main
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            // Empty time range so the query returns quickly regardless
            // of the grant outcome — we only care about the prompt
            // side-effect.
            let now = Date()
            manager.queryActivityStarting(from: now, to: now, to: queue) { _, _ in
                cont.resume()
            }
        }
        return motionStatus()
    }

    private static func requestBluetooth() async -> PermissionGrant {
        guard #available(iOS 13.0, *) else { return .notAvailable }
        return await _BluetoothAuthorizationCoordinator.request()
    }

    private static func requestHealth(type: HKObjectType) async -> PermissionGrant {
        guard HKHealthStore.isHealthDataAvailable() else { return .notAvailable }
        let store = HKHealthStore()
        // `toShare` requires HKSampleType. Types that aren't sample
        // types (e.g. HKCharacteristicType) aren't writable; request
        // read-only in that case. Types that ARE HKSampleType get
        // requested for both read and write so the user sees a
        // single consolidated prompt.
        let shareTypes: Set<HKSampleType> = (type as? HKSampleType).map { [$0] } ?? []
        let readTypes: Set<HKObjectType> = [type]
        do {
            if #available(iOS 15.0, *) {
                try await store.requestAuthorization(
                    toShare: shareTypes, read: readTypes
                )
            } else {
                _ = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                    store.requestAuthorization(
                        toShare: shareTypes, read: readTypes
                    ) { success, _ in
                        cont.resume(returning: success)
                    }
                }
            }
        } catch {
            // Request errored (e.g. HealthKit unavailable at request
            // time despite isHealthDataAvailable reporting true).
            // Fall through to status read.
        }
        return healthStatus(for: type)
    }
}

// MARK: - One-shot delegate coordinators

/// Wraps `CLLocationManager.requestWhenInUseAuthorization()` into an
/// async API. CoreLocation's request API fires the prompt but
/// surfaces the result via the delegate's
/// `locationManagerDidChangeAuthorization(_:)` callback — not via a
/// completion handler. The coordinator retains itself until the
/// callback fires, then releases.
///
/// `@unchecked Sendable`: one-shot class whose mutable state
/// transitions only via the main-queue dispatch in `requestWhenInUse`
/// and the main-queue delegate callback from CoreLocation. No other
/// thread ever touches the instance. Swift's sendability checker
/// can't prove that statically; the invariant holds by construction.
private final class _LocationAuthorizationCoordinator:
    NSObject, CLLocationManagerDelegate, @unchecked Sendable
{
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<PermissionGrant, Never>?
    private var strongSelf: _LocationAuthorizationCoordinator?

    static func requestWhenInUse() async -> PermissionGrant {
        return await withCheckedContinuation { cont in
            let coord = _LocationAuthorizationCoordinator()
            coord.continuation = cont
            coord.strongSelf = coord     // retain until callback
            coord.manager.delegate = coord
            // Must be invoked on main per CoreLocation docs.
            DispatchQueue.main.async {
                coord.manager.requestWhenInUseAuthorization()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // notDetermined fires once before the user responds; wait.
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        resolve(status: status)
    }

    private func resolve(status: CLAuthorizationStatus) {
        guard let cont = continuation else { return }
        continuation = nil
        let grant: PermissionGrant
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            grant = .granted
        case .denied:        grant = .permanentlyDenied
        case .restricted:    grant = .restricted
        case .notDetermined: grant = .denied
        @unknown default:    grant = .denied
        }
        cont.resume(returning: grant)
        manager.delegate = nil
        strongSelf = nil
    }
}

/// Wraps the CoreBluetooth "instantiate CBCentralManager and wait for
/// state" flow into an async API. CBCentralManager's init fires the
/// permission prompt as a side-effect; the user's response surfaces
/// via `centralManagerDidUpdateState(_:)`, at which point
/// `CBManager.authorization` reflects the final state.
@available(iOS 13.0, *)
private final class _BluetoothAuthorizationCoordinator:
    NSObject, CBCentralManagerDelegate, @unchecked Sendable
{
    private var manager: CBCentralManager?
    private var continuation: CheckedContinuation<PermissionGrant, Never>?
    private var strongSelf: _BluetoothAuthorizationCoordinator?

    static func request() async -> PermissionGrant {
        return await withCheckedContinuation { cont in
            let coord = _BluetoothAuthorizationCoordinator()
            coord.continuation = cont
            coord.strongSelf = coord
            // Create CBCentralManager with a main-queue delegate; the
            // init call itself is what triggers the prompt.
            coord.manager = CBCentralManager(delegate: coord, queue: nil)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let auth = CBManager.authorization
        guard auth != .notDetermined else { return }
        guard let cont = continuation else { return }
        continuation = nil
        let grant: PermissionGrant
        switch auth {
        case .allowedAlways: grant = .granted
        case .denied:        grant = .permanentlyDenied
        case .restricted:    grant = .restricted
        case .notDetermined: grant = .denied
        @unknown default:    grant = .denied
        }
        cont.resume(returning: grant)
        manager = nil
        strongSelf = nil
    }
}
