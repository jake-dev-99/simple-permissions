/// Unified permission handling for Flutter apps.
///
/// The entry point is [SimplePermissionsNative.instance] — use it to
/// check or request individual [Permission]s, or group them into
/// `Intention`s when your flow needs a bundle (e.g. `Intention.texting`
/// for SMS-app onboarding).
///
/// ```dart
/// await SimplePermissionsNative.initialize();
///
/// // Single permission
/// final grant = await SimplePermissionsNative.instance.check(
///   const PostNotifications(),
/// );
///
/// // Batch
/// final result = await SimplePermissionsNative.instance.requestAll(
///   const [ReadContacts(), ReadSms(), SendSms()],
/// );
/// if (result.isFullyGranted) { /* start sync */ }
///
/// // Whole-flow intention
/// final ok = await SimplePermissionsNative.instance
///     .requestIntention(Intention.texting);
/// ```
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

import 'src/permission_observer.dart';

export 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

export 'src/permission_observer.dart'
    show
        PermissionObserver,
        PermissionObserverLifecycle,
        WidgetsBindingLifecycle;

/// Facade for the federated simple_permissions plugin.
///
/// All methods are instance methods on [SimplePermissionsNative.instance].
/// [initialize] is static and must be awaited once at app startup
/// before any other call — instance methods throw [StateError] if
/// [initialize] hasn't run.
class SimplePermissionsNative {
  SimplePermissionsNative._();

  /// The singleton instance used for every check / request.
  static final SimplePermissionsNative instance = SimplePermissionsNative._();

  static bool _initialized = false;

  /// Whether [initialize] has completed at least once this process.
  static bool get isInitialized => _initialized;

  /// Initialize the underlying platform implementation. Idempotent; safe
  /// to call multiple times — subsequent calls are no-ops.
  ///
  /// Must be awaited before any [instance] method is used. Typical
  /// placement is in `main()` alongside
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<void> initialize() async {
    if (_initialized) return;
    await SimplePermissionsPlatform.instance.initialize();
    _initialized = true;
  }

  /// Reset the initialization flag — for tests only so each test can
  /// start from a fresh state.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
  }

  /// Current grant status of a single [Permission] without prompting
  /// the user. Returns [PermissionGrant.denied] /
  /// [PermissionGrant.granted] / [PermissionGrant.limited] /
  /// [PermissionGrant.permanentlyDenied] as applicable.
  Future<PermissionGrant> check(Permission permission) {
    return _ensureInitialized().check(permission);
  }

  /// Request a single [Permission] from the user. May surface a system
  /// dialog; caller must handle the async gap where state changes or
  /// the Activity is backgrounded.
  Future<PermissionGrant> request(Permission permission) {
    return _ensureInitialized().request(permission);
  }

  /// Check multiple [Permission]s at once, returning a [PermissionResult]
  /// whose [PermissionResult.permissions] map contains exactly the keys
  /// passed in. Use [PermissionResult.isFullyGranted] for a quick gate.
  Future<PermissionResult> checkAll(List<Permission> permissions) {
    return _ensureInitialized().checkAll(permissions);
  }

  /// Request multiple [Permission]s as a batch. On Android, permissions
  /// belonging to the same group are coalesced into a single system
  /// prompt; runtime permissions outside groups surface as sequential
  /// prompts.
  Future<PermissionResult> requestAll(List<Permission> permissions) {
    return _ensureInitialized().requestAll(permissions);
  }

  /// Whether the current platform supports a given [Permission]. Useful
  /// for cross-platform branching — e.g. `ReadSms` returns false on
  /// iOS, web, desktop.
  Future<bool> isSupported(Permission permission) {
    return _ensureInitialized().isSupported(permission);
  }

  /// Check whether every [Permission] in an [Intention] bundle is
  /// currently granted. Returns a plain bool; see
  /// [checkIntentionDetailed] when you need to know which permissions
  /// in the bundle are missing.
  Future<bool> checkIntention(Intention intention) async {
    final result = await checkAll(intention.permissions);
    return result.isFullyGranted;
  }

  /// Request every [Permission] in an [Intention] bundle. Returns true
  /// iff every permission was granted after the system prompts.
  Future<bool> requestIntention(Intention intention) async {
    final result = await requestAll(intention.permissions);
    return result.isFullyGranted;
  }

  /// Detailed variant of [checkIntention] — returns the full
  /// [PermissionResult] so callers can inspect exactly which
  /// permissions in the intention are missing.
  Future<PermissionResult> checkIntentionDetailed(Intention intention) {
    return checkAll(intention.permissions);
  }

  /// Detailed variant of [requestIntention] — same request flow but
  /// returns the full [PermissionResult] so callers can react to
  /// partial grants.
  Future<PermissionResult> requestIntentionDetailed(Intention intention) {
    return requestAll(intention.permissions);
  }

  /// Open the system settings page for this app. Use when a permission
  /// is [PermissionGrant.permanentlyDenied] and [request] will no
  /// longer surface a prompt.
  Future<bool> openAppSettings() {
    return _ensureInitialized().openAppSettings();
  }

  /// Query the current location-accuracy setting (fine / coarse /
  /// reduced / unknown). Independent of permission grants — a user may
  /// have granted location access but limited it to "approximate" in
  /// system settings.
  Future<LocationAccuracyStatus> checkLocationAccuracy() {
    return _ensureInitialized().checkLocationAccuracy();
  }

  /// Start observing the grant state of [permissions] reactively.
  ///
  /// Returns a [PermissionObserver] whose [PermissionObserver.stream]
  /// emits whenever the observer refreshes — on app resume (catches
  /// grants made via system Settings or the default-app dialog) and
  /// whenever [PermissionObserver.refresh] is called explicitly.
  ///
  /// Dispose the observer when the consumer is torn down; it attaches
  /// a [WidgetsBindingObserver] that wouldn't otherwise be released.
  ///
  /// Typical use: gate read-only vs. full functionality in the UI on
  /// the default-SMS-app / default-dialer role being held.
  ///
  /// ```dart
  /// final observer = SimplePermissionsNative.instance.observe(const [
  ///   DefaultSmsApp(),
  ///   ReceiveSms(),
  /// ]);
  /// observer.stream.listen((result) {
  ///   setState(() => _canSend = result.isFullyGranted);
  /// });
  /// ```
  PermissionObserver observe(
    List<Permission> permissions, {
    PermissionObserverLifecycle? lifecycle,
  }) {
    return createPermissionObserver(
      platform: _ensureInitialized(),
      permissions: permissions,
      lifecycle: lifecycle,
    );
  }

  SimplePermissionsPlatform _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'SimplePermissionsNative is not initialized. Call '
        'SimplePermissionsNative.initialize() before using the API.',
      );
    }
    return SimplePermissionsPlatform.instance;
  }
}
