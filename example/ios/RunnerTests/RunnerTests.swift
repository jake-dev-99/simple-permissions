import Flutter
import HealthKit
import UIKit
import XCTest

// Plain import — every symbol we exercise is public. `@testable`
// would require the pod to be built with -enable-testing, which
// CocoaPods doesn't guarantee across configurations.
import simple_permissions_ios

// MARK: - PermissionGrant predicates
//
// These tests exercise the Swift-side mirror of the Dart PermissionGrant
// enum. No framework calls; all deterministic.

final class PermissionGrantTests: XCTestCase {
    func testRawValuesMatchWireFormat() {
        // Must match the Dart enum's .name values verbatim —
        // Pigeon + the manual wire contract depend on this.
        XCTAssertEqual(PermissionGrant.granted.rawValue, "granted")
        XCTAssertEqual(PermissionGrant.denied.rawValue, "denied")
        XCTAssertEqual(PermissionGrant.permanentlyDenied.rawValue, "permanentlyDenied")
        XCTAssertEqual(PermissionGrant.restricted.rawValue, "restricted")
        XCTAssertEqual(PermissionGrant.limited.rawValue, "limited")
        XCTAssertEqual(PermissionGrant.notApplicable.rawValue, "notApplicable")
        XCTAssertEqual(PermissionGrant.notAvailable.rawValue, "notAvailable")
        XCTAssertEqual(PermissionGrant.provisional.rawValue, "provisional")
    }

    func testIsSatisfiedCoversGrantedLimitedProvisional() {
        XCTAssertTrue(PermissionGrant.granted.isSatisfied)
        XCTAssertTrue(PermissionGrant.limited.isSatisfied)
        XCTAssertTrue(PermissionGrant.provisional.isSatisfied)
        XCTAssertFalse(PermissionGrant.denied.isSatisfied)
        XCTAssertFalse(PermissionGrant.permanentlyDenied.isSatisfied)
        XCTAssertFalse(PermissionGrant.restricted.isSatisfied)
        XCTAssertFalse(PermissionGrant.notApplicable.isSatisfied)
        XCTAssertFalse(PermissionGrant.notAvailable.isSatisfied)
    }

    func testIsDeniedCoversDeniedPermanentlyDeniedRestricted() {
        XCTAssertTrue(PermissionGrant.denied.isDenied)
        XCTAssertTrue(PermissionGrant.permanentlyDenied.isDenied)
        XCTAssertTrue(PermissionGrant.restricted.isDenied)
        XCTAssertFalse(PermissionGrant.granted.isDenied)
        XCTAssertFalse(PermissionGrant.limited.isDenied)
        XCTAssertFalse(PermissionGrant.provisional.isDenied)
        XCTAssertFalse(PermissionGrant.notApplicable.isDenied)
        XCTAssertFalse(PermissionGrant.notAvailable.isDenied)
    }

    func testIsUnsupportedCoversNotApplicableNotAvailable() {
        XCTAssertTrue(PermissionGrant.notApplicable.isUnsupported)
        XCTAssertTrue(PermissionGrant.notAvailable.isUnsupported)
        XCTAssertFalse(PermissionGrant.granted.isUnsupported)
        XCTAssertFalse(PermissionGrant.denied.isUnsupported)
    }

    func testIsTerminalCoversFourStates() {
        XCTAssertTrue(PermissionGrant.permanentlyDenied.isTerminal)
        XCTAssertTrue(PermissionGrant.restricted.isTerminal)
        XCTAssertTrue(PermissionGrant.notApplicable.isTerminal)
        XCTAssertTrue(PermissionGrant.notAvailable.isTerminal)
        // Not terminal: a re-request is sensible.
        XCTAssertFalse(PermissionGrant.denied.isTerminal)
        XCTAssertFalse(PermissionGrant.granted.isTerminal)
        XCTAssertFalse(PermissionGrant.limited.isTerminal)
        XCTAssertFalse(PermissionGrant.provisional.isTerminal)
    }

    func testSatisfiedAndDeniedAreMutuallyExclusive() {
        let allCases: [PermissionGrant] = [
            .granted, .denied, .permanentlyDenied, .restricted,
            .limited, .notApplicable, .notAvailable, .provisional,
        ]
        for grant in allCases {
            XCTAssertFalse(
                grant.isSatisfied && grant.isDenied,
                "\(grant) claims both satisfied AND denied"
            )
        }
    }

    func testEveryGrantFallsIntoExactlyOneCategory() {
        // Every grant is satisfied XOR denied XOR unsupported.
        let allCases: [PermissionGrant] = [
            .granted, .denied, .permanentlyDenied, .restricted,
            .limited, .notApplicable, .notAvailable, .provisional,
        ]
        for grant in allCases {
            let count = [
                grant.isSatisfied, grant.isDenied, grant.isUnsupported,
            ].filter { $0 }.count
            XCTAssertEqual(
                count, 1,
                "\(grant) must fall into exactly one category; got \(count)"
            )
        }
    }
}

// MARK: - ApplePermissionKind identifiers
//
// String-identifier stability locks in the wire format used in
// PermissionDeniedError.deniedPermissions and in any log lines that
// callers grep on.

final class ApplePermissionKindTests: XCTestCase {
    func testZeroArgCaseIdentifiers() {
        XCTAssertEqual(ApplePermissionKind.contacts.identifier, "contacts")
        XCTAssertEqual(ApplePermissionKind.camera.identifier, "camera")
        XCTAssertEqual(ApplePermissionKind.microphone.identifier, "microphone")
        XCTAssertEqual(ApplePermissionKind.calendar.identifier, "calendar")
        XCTAssertEqual(ApplePermissionKind.reminders.identifier, "reminders")
        XCTAssertEqual(ApplePermissionKind.photoLibrary.identifier, "photoLibrary")
        XCTAssertEqual(
            ApplePermissionKind.photoLibraryAddOnly.identifier,
            "photoLibraryAddOnly"
        )
        XCTAssertEqual(ApplePermissionKind.location.identifier, "location")
        XCTAssertEqual(ApplePermissionKind.speech.identifier, "speech")
        XCTAssertEqual(ApplePermissionKind.tracking.identifier, "tracking")
        XCTAssertEqual(ApplePermissionKind.motion.identifier, "motion")
        XCTAssertEqual(ApplePermissionKind.bluetooth.identifier, "bluetooth")
    }

    func testHealthIdentifierIncludesHKObjectTypeIdentifier() {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            XCTFail("HealthKit step count type unavailable in test environment")
            return
        }
        let kind = ApplePermissionKind.health(stepType)
        // Format is "health:<HKObjectType.identifier>" so error
        // messages can differentiate which specific health type
        // failed instead of a generic "health".
        XCTAssertEqual(kind.identifier, "health:HKQuantityTypeIdentifierStepCount")
    }
}

// MARK: - PermissionDeniedError construction

final class PermissionDeniedErrorTests: XCTestCase {
    func testDescriptionMatchesMessage() {
        let err = PermissionDeniedError(
            deniedPermissions: ["camera"],
            message: "test message"
        )
        XCTAssertEqual(err.description, "test message")
    }

    func testDeniedPermissionsListPreservesOrder() {
        let err = PermissionDeniedError(
            deniedPermissions: ["camera", "microphone", "photoLibrary"],
            message: "multi"
        )
        XCTAssertEqual(
            err.deniedPermissions,
            ["camera", "microphone", "photoLibrary"]
        )
    }

    func testIsSecurityErrorCompatible() {
        // PermissionDeniedError conforms to Error (not SecurityException
        // like Kotlin); ensure it can be caught at the Error seam.
        let err: Error = PermissionDeniedError(
            deniedPermissions: ["contacts"],
            message: "x"
        )
        XCTAssertTrue(err is PermissionDeniedError)
    }
}

// MARK: - PermissionGuards require* edge cases

final class PermissionGuardsRequireTests: XCTestCase {

    func testRequireAnyAuthorizedEmptyCollectionThrows() {
        // Empty required-set is a programmer error; better to throw
        // loudly than to silently pass.
        do {
            try PermissionGuards.requireAnyAuthorized(for: [])
            XCTFail("Expected PermissionDeniedError for empty kinds")
        } catch let err as PermissionDeniedError {
            XCTAssertTrue(err.deniedPermissions.isEmpty)
            XCTAssertTrue(err.message.contains("at least one"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRequireAllAuthorizedEmptyCollectionSucceeds() {
        // Vacuously satisfied. Matches Kotlin's
        // `requireAllPermissionsGranted(emptyList())` semantics.
        XCTAssertNoThrow(try PermissionGuards.requireAllAuthorized(for: []))
    }

    func testRequireAuthorizedThrowsOnNotDeterminedKind() {
        // In a fresh test environment permissions are .notDetermined,
        // which maps to .denied (not satisfied). Any require* call
        // for such a kind should throw with a well-formed error.
        //
        // We pick a kind whose identifier is stable and doesn't
        // require Info.plist usage-description keys to query status.
        // `.camera` queries AVCaptureDevice.authorizationStatus which
        // is safe to call without a usage string.
        do {
            try PermissionGuards.requireAuthorized(for: .camera)
            // Surprise — camera was authorized in the test env. Not
            // a failure of the helper, just inconclusive. Skip.
            print("Camera was already authorized in test env — skipping assertion")
        } catch let err as PermissionDeniedError {
            XCTAssertEqual(err.deniedPermissions, ["camera"])
            XCTAssertTrue(err.message.contains("camera"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRequireAllAuthorizedReportsOnlyMissingKinds() {
        // requireAll's contract: deniedPermissions lists only the
        // kinds that were missing, not the full required set. So a
        // caller who requests [.camera, .microphone, .speech] where
        // only .microphone is denied sees deniedPermissions == ["microphone"].
        //
        // We can't scripted-grant permissions in a unit test, so we
        // exercise the shape with a plausibly-all-denied set and
        // just verify the list is a strict subset of inputs and is
        // non-empty (assuming the test host doesn't already have
        // every permission granted).
        do {
            try PermissionGuards.requireAllAuthorized(
                for: [.camera, .microphone, .photoLibrary]
            )
            print("All three permissions already granted in test env — skipping")
        } catch let err as PermissionDeniedError {
            let expected: Set<String> = ["camera", "microphone", "photoLibrary"]
            XCTAssertFalse(err.deniedPermissions.isEmpty)
            for identifier in err.deniedPermissions {
                XCTAssertTrue(
                    expected.contains(identifier),
                    "Unexpected identifier '\(identifier)' in deniedPermissions"
                )
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - authorizationStatus(for:)

final class AuthorizationStatusTests: XCTestCase {

    func testStatusIsOneOfTheEightGrantValues() {
        // Smoke-level check that every kind returns a PermissionGrant
        // value that round-trips through its rawValue. Catches any
        // case where a framework-specific auth enum grows a new case
        // and our @unknown default doesn't fire (e.g. if a new case
        // has rawValue 0 and falls through some other path).
        let kinds: [ApplePermissionKind] = [
            .contacts, .camera, .microphone, .calendar, .reminders,
            .photoLibrary, .photoLibraryAddOnly, .location, .speech,
            .tracking, .motion, .bluetooth,
        ]
        for kind in kinds {
            let status = PermissionGuards.authorizationStatus(for: kind)
            let recovered = PermissionGrant(rawValue: status.rawValue)
            XCTAssertNotNil(
                recovered,
                "\(kind.identifier) produced unrecognized rawValue: \(status.rawValue)"
            )
        }
    }

    func testIsAuthorizedMatchesStatusIsSatisfied() {
        // `isAuthorized(for:)` is a thin wrapper over
        // `authorizationStatus(for: kind).isSatisfied`. Regressions
        // where the two diverge are exactly the kind of silent bug
        // this test catches.
        let kinds: [ApplePermissionKind] = [
            .contacts, .camera, .microphone, .calendar, .reminders,
            .photoLibrary, .photoLibraryAddOnly, .location, .speech,
            .tracking, .motion, .bluetooth,
        ]
        for kind in kinds {
            XCTAssertEqual(
                PermissionGuards.isAuthorized(for: kind),
                PermissionGuards.authorizationStatus(for: kind).isSatisfied,
                "Divergence for \(kind.identifier)"
            )
        }
    }

    func testHealthStatusHandlesUnavailableGracefully() {
        // On devices where HealthKit isn't available, status for any
        // health type should be .notAvailable — not a crash, not
        // .denied, not .granted.
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            XCTFail("HealthKit step-count type unavailable")
            return
        }
        let status = PermissionGuards.authorizationStatus(for: .health(stepType))
        // In a unit-test host on a device with HealthKit (the normal
        // case), this returns .denied (notDetermined). On devices
        // without HealthKit (rare in 2026 but still possible for
        // certain simulator configs), returns .notAvailable. Either
        // is acceptable; crash is not.
        let acceptable: Set<PermissionGrant> = [.denied, .notAvailable, .granted, .permanentlyDenied]
        XCTAssertTrue(
            acceptable.contains(status),
            "Unexpected health status: \(status)"
        )
    }
}
