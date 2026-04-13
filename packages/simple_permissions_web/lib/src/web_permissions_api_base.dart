/// Abstract interface for browser permission operations.
///
/// Extracted to enable unit testing with a mock implementation —
/// actual browser APIs are not available in the VM test environment.
abstract class WebPermissionsApi {
  /// Query the current state of a permission by its web API name.
  ///
  /// Returns `'granted'`, `'denied'`, `'prompt'`, or `null` if the
  /// Permissions API is unavailable.
  Future<String?> queryPermission(String name);

  /// Request camera access via `getUserMedia({video: true})`.
  Future<bool> requestCamera();

  /// Request microphone access via `getUserMedia({audio: true})`.
  Future<bool> requestMicrophone();

  /// Request geolocation access via `getCurrentPosition()`.
  Future<bool> requestGeolocation();

  /// Request notification permission via `Notification.requestPermission()`.
  ///
  /// Returns the result string: `'granted'`, `'denied'`, or `'default'`.
  Future<String> requestNotifications();

  /// Attempt to open app settings. Always returns `false` on web —
  /// browsers don't expose a settings page for individual sites.
  Future<bool> openAppSettings();
}
