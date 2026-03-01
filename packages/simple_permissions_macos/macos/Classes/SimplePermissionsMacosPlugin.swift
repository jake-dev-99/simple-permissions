import AVFoundation
import Contacts
import CoreLocation
import EventKit
import FlutterMacOS
import Photos
import AppKit
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

/// All macOS permission handlers conform to this protocol.
private protocol PermissionHandler {
  func check(completion: @escaping (String) -> Void)
  func request(completion: @escaping (String) -> Void)
  /// Whether this permission is supported on the running macOS version.
  var isSupported: Bool { get }
}

// MARK: - Plugin Entry Point

public class SimplePermissionsMacosPlugin: NSObject, FlutterPlugin, PermissionsMacosHostApi {

  /// Handler registry keyed on permission identifier strings.
  private lazy var handlers: [String: PermissionHandler] = buildHandlerRegistry()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SimplePermissionsMacosPlugin()
    PermissionsMacosHostApiSetup.setUp(
      binaryMessenger: registrar.messenger,
      api: instance
    )
  }

  // MARK: - PermissionsMacosHostApi

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
    // macOS 13+ uses System Settings; older versions use System Preferences.
    // Opening the app's own privacy settings is limited — we open the
    // Security & Privacy pane as the best available option.
    if #available(macOS 13.0, *) {
      // System Settings URL scheme
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
        NSWorkspace.shared.open(url)
        completion(.success(true))
        return
      }
    }

    // Fallback: open System Preferences Security & Privacy pane
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
      NSWorkspace.shared.open(url)
      completion(.success(true))
    } else {
      completion(.success(false))
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
    "coarse_location": LocationHandler(),
    "fine_location": LocationHandler(),

    // Calendar
    "read_calendar": CalendarHandler(entityType: .event),
    "write_calendar": CalendarHandler(entityType: .event),
    "read_reminders": CalendarHandler(entityType: .reminder),
    "write_reminders": CalendarHandler(entityType: .reminder),
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
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    completion(mapAVStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    switch status {
    case .authorized:
      completion(GrantWire.granted.rawValue)
    case .denied:
      completion(GrantWire.permanentlyDenied.rawValue)
    case .restricted:
      completion(GrantWire.restricted.rawValue)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { granted in
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

private class LocationHandler: NSObject, PermissionHandler, CLLocationManagerDelegate {
  private var manager: CLLocationManager?
  private var pendingCompletion: ((String) -> Void)?

  var isSupported: Bool { true }

  func check(completion: @escaping (String) -> Void) {
    let manager = CLLocationManager()
    let status: CLAuthorizationStatus
    if #available(macOS 11.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    completion(mapLocationStatus(status))
  }

  func request(completion: @escaping (String) -> Void) {
    ensureMainThread {
      let mgr = CLLocationManager()
      let status: CLAuthorizationStatus
      if #available(macOS 11.0, *) {
        status = mgr.authorizationStatus
      } else {
        status = CLLocationManager.authorizationStatus()
      }

      switch status {
      case .authorizedAlways:
        completion(GrantWire.granted.rawValue)
        return
      case .denied:
        completion(GrantWire.permanentlyDenied.rawValue)
        return
      case .restricted:
        completion(GrantWire.restricted.rawValue)
        return
      case .notDetermined:
        break // Fall through to request
      default:
        completion(GrantWire.denied.rawValue)
        return
      }

      // Store state for delegate callback
      self.manager = mgr
      self.pendingCompletion = completion
      mgr.delegate = self

      // macOS uses requestAlwaysAuthorization (no whenInUse before macOS 11.0).
      // On macOS 11.0+ requestWhenInUseAuthorization is available but the
      // system usually prompts for "always" anyway. Use always for consistency.
      mgr.requestAlwaysAuthorization()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let completion = pendingCompletion else { return }

    let status: CLAuthorizationStatus
    if #available(macOS 11.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }

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
      if #available(macOS 14.0, *) {
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
