import CoreLocation
import Flutter
import UIKit

public class SimplePermissionsIosPlugin: NSObject, FlutterPlugin, PermissionsIosHostApi {
  private lazy var handlers: [String: PermissionHandler] = buildPermissionHandlerRegistry()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SimplePermissionsIosPlugin()
    PermissionsIosHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: instance
    )
  }

  func checkPermission(identifier: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard let handler = handlers[identifier] else {
      completion(.success(PermissionGrant.notApplicable.rawValue))
      return
    }
    guard handler.isSupported else {
      completion(.success(PermissionGrant.notAvailable.rawValue))
      return
    }
    handler.check { wire in
      completion(.success(wire))
    }
  }

  func requestPermission(identifier: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard let handler = handlers[identifier] else {
      completion(.success(PermissionGrant.notApplicable.rawValue))
      return
    }
    guard handler.isSupported else {
      completion(.success(PermissionGrant.notAvailable.rawValue))
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
