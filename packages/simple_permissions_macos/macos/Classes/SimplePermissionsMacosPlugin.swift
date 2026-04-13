import AppKit
import CoreLocation
import FlutterMacOS

public class SimplePermissionsMacosPlugin: NSObject, FlutterPlugin, PermissionsMacosHostApi {
  private lazy var handlers: [String: PermissionHandler] = buildPermissionHandlerRegistry()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SimplePermissionsMacosPlugin()
    PermissionsMacosHostApiSetup.setUp(
      binaryMessenger: registrar.messenger,
      api: instance
    )
  }

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
    handlers[identifier]?.isSupported ?? false
  }

  func openAppSettings(completion: @escaping (Result<Bool, Error>) -> Void) {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
      completion(.success(NSWorkspace.shared.open(url)))
    } else {
      completion(.success(false))
    }
  }

  func checkLocationAccuracy(completion: @escaping (Result<String, Error>) -> Void) {
    let status: CLAuthorizationStatus
    if #available(macOS 11.0, *) {
      status = CLLocationManager().authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      completion(.success("precise"))
    case .notDetermined, .denied, .restricted:
      completion(.success("none"))
    @unknown default:
      completion(.success("none"))
    }
  }
}
