import AVFoundation
import AppTrackingTransparency
import CoreBluetooth
import Contacts
import CoreLocation
import CoreMotion
import EventKit
import Flutter
import HealthKit
import Photos
import Speech
import UIKit
import UserNotifications

// MARK: - Permission Grant Wire Values

/// Wire values sent back to Dart, matching PermissionGrant enum names.
private enum GrantWire: String {
  case granted
  case denied
  case permanentlyDenied
  case restricted
  case limited
  case notApplicable
  case notAvailable
  case provisional
}

// MARK: - Permission Handler Protocol

/// All iOS permission handlers conform to this protocol.
private protocol PermissionHandler {
  func check(completion: @escaping (String) -> Void)
  func request(completion: @escaping (String) -> Void)
  /// Whether this permission is supported on the running iOS version.
  var isSupported: Bool { get }
}

// MARK: - Plugin Entry Point

public class SimplePermissionsIosPlugin: NSObject, FlutterPlugin, PermissionsIosHostApi {

  /// Handler registry keyed on permission identifier strings.
  private lazy var handlers: [String: PermissionHandler] = buildHandlerRegistry()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SimplePermissionsIosPlugin()
    PermissionsIosHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: instance
    )
  }

  // MARK: - PermissionsIosHostApi

  func checkPermission(identifier: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard let handler = handlers[identifier] else {
      completion(.success(GrantWire.notApplicable.rawValue))
      return
    }
    guard handler.isSupported else {
      completion(.success(GrantWire.notAvailable.rawValue))
      return
    }
    handler.check { wire in
      completion(.success(wire))
    }
  }

  func requestPermission(identifier: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard let handler = handlers[identifier] else {
      completion(.success(GrantWire.notApplicable.rawValue))
      return
    }
    guard handler.isSupported else {
      completion(.success(GrantWire.notAvailable.rawValue))
      return
    }
    handler.request { wire in
      completion(.success(wire))
    }
  }

  func isSupported(identifier: String) throws -> Bool {
    guard let handler = handlers[identifier] else {
      return false
    }
    return handler.isSupported
  }

  func openAppSettings(completion: @escaping (Result<Bool, Error>) -> Void) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      completion(.success(false))
      return
    }
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:]) { success in
        completion(.success(success))
      }
    }
  }

  func checkLocationAccuracy(completion: @escaping (Result<String, Error>) -> Void) {
    guard #available(iOS 14.0, *) else {
      completion(.success("notAvailable"))
      return
    }

    let manager = CLLocationManager()
    let authStatus = manager.authorizationStatus
    switch authStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      completion(.success(
        manager.accuracyAuthorization == .reducedAccuracy ? "reduced" : "precise"
      ))
    case .notDetermined, .denied, .restricted:
      completion(.success("none"))
    @unknown default:
      completion(.success("none"))
    }
  }
}

// MARK: - Handler Registry

private func buildHandlerRegistry() -> [String: PermissionHandler] {
  return [
    // Contacts
    "read_contacts": ContactsHandler(),
    "write_contacts": ContactsHandler(),

    // Camera
    "camera_access": CameraHandler(),

    // Microphone
    "record_audio": MicrophoneHandler(),

    // Photos / Media
    "read_media_images": PhotoLibraryHandler(),
    "read_media_video": PhotoLibraryHandler(),

    // Notifications
    "post_notifications": NotificationHandler(),

    // Location
    "coarse_location": LocationHandler(level: .whenInUse),
    "fine_location": LocationHandler(level: .whenInUse),
    "background_location": LocationHandler(level: .always),

    // Calendar
    "read_calendar": CalendarHandler(entityType: .event),
    "write_calendar": CalendarHandler(entityType: .event),
    "read_reminders": CalendarHandler(entityType: .reminder),
    "write_reminders": CalendarHandler(entityType: .reminder),

    // Bluetooth (iOS 13+ authorization model shared across BLE operations)
    "bluetooth_connect": BluetoothHandler(),
    "bluetooth_scan": BluetoothHandler(),
    "bluetooth_advertise": BluetoothHandler(),

    // Speech recognition
    "speech_recognition": SpeechHandler(),

    // Health
    "read_health": HealthHandler(),
    "write_health": HealthHandler(),

    // Sensors / Motion
    "body_sensors": MotionHandler(),
    "activity_recognition": MotionHandler(),

    // Tracking (ATT) — iOS 14+
    "app_tracking_transparency": TrackingHandler(),
  ]
}

// MARK: - Thread Safety

private func ensureMainThread(_ block: @escaping () -> Void) {
  if Thread.isMainThread {
    block()
  } else {
    DispatchQueue.main.async { block() }
  }
}

// MARK: - Contacts Handler

private class ContactsHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    completion(mapContactsStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    switch status {
    case .authorized:
      completion(GrantWire.granted.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      CNContactStore().requestAccess(for: .contacts) { granted, _ in
        ensureMainThread {
          completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapContactsStatus(_ status: CNAuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}

// MARK: - Camera Handler

private class CameraHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    completion(mapAVStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
      completion(GrantWire.granted.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        ensureMainThread {
          completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapAVStatus(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}

// MARK: - Microphone Handler

private class MicrophoneHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let status = AVAudioSession.sharedInstance().recordPermission
    completion(mapRecordStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = AVAudioSession.sharedInstance().recordPermission
    switch status {
    case .granted:
      completion(GrantWire.granted.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .undetermined:
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        ensureMainThread {
          completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapRecordStatus(_ status: AVAudioSession.RecordPermission) -> String {
    switch status {
    case .granted: return GrantWire.granted.rawValue
    case .undetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}

// MARK: - Photo Library Handler

private class PhotoLibraryHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    completion(mapPhotoStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    switch status {
    case .authorized:
      completion(GrantWire.granted.rawValue)
    case .limited:
      completion(GrantWire.limited.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
        ensureMainThread {
          completion(self.mapPhotoStatus(newStatus))
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapPhotoStatus(_ status: PHAuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .limited: return GrantWire.limited.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}

// MARK: - Notification Handler

private class NotificationHandler: PermissionHandler {
  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      ensureMainThread {
        completion(self.mapNotificationStatus(settings.authorizationStatus))
      }
    }
  }

  func request(completion: @escaping (String) -> Void) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, _ in
      if granted {
        ensureMainThread { completion(GrantWire.granted.rawValue) }
        return
      }
      // Re-check to distinguish denied from permanently denied
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        ensureMainThread {
          let wire = settings.authorizationStatus == .denied
            ? GrantWire.permanentlyDenied.rawValue
            : GrantWire.denied.rawValue
          completion(wire)
        }
      }
    }
  }

  private func mapNotificationStatus(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .provisional: return GrantWire.provisional.rawValue
    case .ephemeral: return GrantWire.provisional.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}

// MARK: - Location Handler

private enum LocationLevel {
  case whenInUse
  case always
}

private class LocationHandler: NSObject, PermissionHandler, CLLocationManagerDelegate {
  let level: LocationLevel
  private var manager: CLLocationManager?
  private var pendingCompletion: ((String) -> Void)?

  init(level: LocationLevel) {
    self.level = level
  }

  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let manager = CLLocationManager()
    let status = manager.authorizationStatus
    completion(mapLocationStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    ensureMainThread {
      let mgr = CLLocationManager()
      let status = mgr.authorizationStatus

      switch status {
      case .authorizedAlways:
        completion(GrantWire.granted.rawValue)
        return
      case .authorizedWhenInUse:
        if self.level == .whenInUse {
          completion(GrantWire.granted.rawValue)
          return
        }
        // Need to upgrade to always — fall through to request
      case .denied:
        completion(GrantWire.permanentlyDenied.rawValue)
        return
      case .restricted:
        completion(GrantWire.restricted.rawValue)
        return
      case .notDetermined:
        break // Fall through to request
      @unknown default:
        completion(GrantWire.denied.rawValue)
        return
      }

      // Store state for delegate callback
      self.manager = mgr
      self.pendingCompletion = completion
      mgr.delegate = self

      switch self.level {
      case .whenInUse:
        mgr.requestWhenInUseAuthorization()
      case .always:
        mgr.requestAlwaysAuthorization()
      }
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let completion = pendingCompletion else { return }
    let status = manager.authorizationStatus

    // Ignore initial .notDetermined callback
    guard status != .notDetermined else { return }

    ensureMainThread {
      completion(self.mapLocationStatus(status))
      self.pendingCompletion = nil
      self.manager = nil
    }
  }

  private func mapLocationStatus(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .authorizedAlways:
      return GrantWire.granted.rawValue
    case .authorizedWhenInUse:
      return level == .whenInUse
        ? GrantWire.granted.rawValue
        : GrantWire.limited.rawValue  // Has whenInUse but wanted always
    case .notDetermined:
      return GrantWire.denied.rawValue
    case .denied:
      return GrantWire.permanentlyDenied.rawValue
    case .restricted:
      return GrantWire.restricted.rawValue
    @unknown default:
      return GrantWire.denied.rawValue
    }
  }
}

// MARK: - Calendar Handler

private class CalendarHandler: PermissionHandler {
  let entityType: EKEntityType

  init(entityType: EKEntityType) {
    self.entityType = entityType
  }

  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let status = EKEventStore.authorizationStatus(for: entityType)
    completion(mapCalendarStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = EKEventStore.authorizationStatus(for: entityType)
    switch status {
    case .authorized, .fullAccess:
      completion(GrantWire.granted.rawValue)
    case .writeOnly:
      completion(GrantWire.limited.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      if #available(iOS 17.0, *) {
        let store = EKEventStore()
        switch entityType {
        case .event:
          store.requestFullAccessToEvents { granted, _ in
            ensureMainThread {
              completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
            }
          }
        case .reminder:
          store.requestFullAccessToReminders { granted, _ in
            ensureMainThread {
              completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
            }
          }
        @unknown default:
          store.requestAccess(to: entityType) { granted, _ in
            ensureMainThread {
              completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
            }
          }
        }
      } else {
        EKEventStore().requestAccess(to: entityType) { granted, _ in
          ensureMainThread {
            completion(granted ? GrantWire.granted.rawValue : GrantWire.denied.rawValue)
          }
        }
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  private func mapCalendarStatus(_ status: EKAuthorizationStatus) -> String {
    switch status {
    case .authorized, .fullAccess: return GrantWire.granted.rawValue
    case .writeOnly: return GrantWire.limited.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}

// MARK: - Bluetooth Handler

private class BluetoothHandler: NSObject, PermissionHandler, CBCentralManagerDelegate {
  private var centralManager: CBCentralManager?
  private var pendingCompletion: ((String) -> Void)?

  var isSupported: Bool {
    if #available(iOS 13.0, *) {
      return true
    }
    return false
  }

  func check(completion: @escaping (String) -> Void) {
    guard #available(iOS 13.0, *) else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }
    completion(mapBluetoothStatus(CBManager.authorization))
  }

  func request(completion: @escaping (String) -> Void) {
    guard #available(iOS 13.0, *) else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }

    let status = CBManager.authorization
    switch status {
    case .allowedAlways:
      completion(GrantWire.granted.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      ensureMainThread {
        self.pendingCompletion = completion
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
      }
    @unknown default:
      completion(GrantWire.denied.rawValue)
    }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard let completion = pendingCompletion else { return }
    guard #available(iOS 13.0, *) else {
      completion(GrantWire.notAvailable.rawValue)
      pendingCompletion = nil
      centralManager = nil
      return
    }

    let status = CBManager.authorization
    guard status != .notDetermined else { return }
    completion(mapBluetoothStatus(status))
    pendingCompletion = nil
    centralManager = nil
  }

  @available(iOS 13.0, *)
  private func mapBluetoothStatus(_ status: CBManagerAuthorization) -> String {
    switch status {
    case .allowedAlways: return GrantWire.granted.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}

// MARK: - Speech Handler

private class SpeechHandler: PermissionHandler {
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

// MARK: - Health Handler

private class HealthHandler: PermissionHandler {
  var isSupported: Bool {
    return HKHealthStore.isHealthDataAvailable()
  }

  func check(completion: @escaping (String) -> Void) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }
    // HealthKit authorization is per-type. We use step count as a proxy here,
    // which indicates general HealthKit availability but not every type.
    let store = HKHealthStore()
    // Requesting the proxy type keeps this plugin API generic.
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let status = store.authorizationStatus(for: stepType)
    switch status {
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

// MARK: - Motion Handler

private class MotionHandler: PermissionHandler {
  var isSupported: Bool {
    return CMMotionActivityManager.isActivityAvailable()
  }

  func check(completion: @escaping (String) -> Void) {
    guard CMMotionActivityManager.isActivityAvailable() else {
      completion(GrantWire.notAvailable.rawValue)
      return
    }
    // CoreMotion shows permission dialog on first data access.
    // A quick query determines current authorization state.
    let manager = CMMotionActivityManager()
    let now = Date()
    manager.queryActivityStarting(from: now, to: now, to: .main) { _, error in
      if let error = error as NSError? {
        if error.domain == CMErrorDomain
          && error.code == CMError.motionActivityNotAuthorized.rawValue
        {
          completion(GrantWire.permanentlyDenied.rawValue)
        } else if error.domain == CMErrorDomain
          && error.code == CMError.motionActivityNotEntitled.rawValue
        {
          completion(GrantWire.restricted.rawValue)
        } else {
          completion(GrantWire.denied.rawValue)
        }
      } else {
        completion(GrantWire.granted.rawValue)
      }
      manager.stopActivityUpdates()
    }
  }

  func request(completion: @escaping (String) -> Void) {
    // CoreMotion shows its permission dialog on first data access.
    check(completion: completion)
  }
}

// MARK: - App Tracking Transparency Handler

private class TrackingHandler: PermissionHandler {
  var isSupported: Bool {
    if #available(iOS 14.0, *) {
      return true
    }
    return false
  }

  func check(completion: @escaping (String) -> Void) {
    if #available(iOS 14.0, *) {
      let status = ATTrackingManager.trackingAuthorizationStatus
      completion(mapTrackingStatus(status))
    } else {
      completion(GrantWire.notAvailable.rawValue)
    }
  }

  func request(completion: @escaping (String) -> Void) {
    if #available(iOS 14.0, *) {
      let current = ATTrackingManager.trackingAuthorizationStatus
      switch current {
      case .authorized:
        completion(GrantWire.granted.rawValue)
      case .denied:
        completion(GrantWire.permanentlyDenied.rawValue)
      case .restricted:
        completion(GrantWire.restricted.rawValue)
      case .notDetermined:
        ATTrackingManager.requestTrackingAuthorization { status in
          ensureMainThread {
            completion(self.mapTrackingStatus(status))
          }
        }
      @unknown default:
        completion(GrantWire.denied.rawValue)
      }
    } else {
      completion(GrantWire.notAvailable.rawValue)
    }
  }

  @available(iOS 14.0, *)
  private func mapTrackingStatus(_ status: ATTrackingManager.AuthorizationStatus) -> String {
    switch status {
    case .authorized: return GrantWire.granted.rawValue
    case .notDetermined: return GrantWire.denied.rawValue
    case .denied: return GrantWire.permanentlyDenied.rawValue
    case .restricted: return GrantWire.restricted.rawValue
    @unknown default: return GrantWire.denied.rawValue
    }
  }
}
