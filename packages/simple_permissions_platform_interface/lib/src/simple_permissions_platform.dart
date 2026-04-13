import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'permission_grant.dart';
import 'permission_result.dart';
import 'location_accuracy_status.dart';
import 'permissions/permission.dart';

/// The platform interface for simple_permissions.
///
/// Platform implementations (Android, iOS, macOS, etc.) extend this class
/// and register themselves via [instance].
///
/// The API uses [Permission] sealed classes instead of string identifiers:
///
/// - [check] / [request] — single permission
/// - [checkAll] / [requestAll] — batch permissions
/// - [isSupported] — version/platform check
/// - [openAppSettings] — navigate to app settings
abstract class SimplePermissionsPlatform extends PlatformInterface {
  SimplePermissionsPlatform() : super(token: _token);

  static final Object _token = Object();
  static SimplePermissionsPlatform _instance = _NoopSimplePermissionsPlatform();
  static SimplePermissionsPlatform get instance => _instance;
  static set instance(SimplePermissionsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  static Object get token => _token;

  // ===========================================================================
  // v2 API — Permission sealed classes
  // ===========================================================================

  /// Perform any asynchronous platform warmup needed for deterministic reads.
  ///
  /// Implementations may use this to cache platform capabilities that are
  /// otherwise discovered lazily.
  Future<void> initialize() async {}

  /// Check the current grant state of a single [permission].
  ///
  /// Does not prompt the user. Returns the current state as reported by
  /// the operating system.
  Future<PermissionGrant> check(Permission permission);

  /// Request a single [permission] from the user.
  ///
  /// If already granted, returns [PermissionGrant.granted] without prompting.
  /// Otherwise shows the appropriate system dialog.
  Future<PermissionGrant> request(Permission permission);

  /// Check the current grant state of multiple [permissions].
  ///
  /// Default implementation calls [check] for each permission sequentially.
  /// Platform implementations may override for batch optimization.
  Future<PermissionResult> checkAll(List<Permission> permissions) async {
    final results = <Permission, PermissionGrant>{};
    for (final permission in permissions) {
      results[permission] = await check(permission);
    }
    return PermissionResult(results);
  }

  /// Request multiple [permissions] from the user.
  ///
  /// Default implementation calls [request] for each permission sequentially.
  /// Platform implementations may override for batch optimization.
  ///
  /// Implementations that batch runtime permissions may perform denial
  /// classification (e.g., rationale checks) in a single post-request pass
  /// rather than matching the exact call shape of single-permission [request].
  Future<PermissionResult> requestAll(List<Permission> permissions) async {
    final results = <Permission, PermissionGrant>{};
    for (final permission in permissions) {
      results[permission] = await request(permission);
    }
    return PermissionResult(results);
  }

  /// Whether this [permission] is meaningful on the current platform and
  /// OS version.
  ///
  /// Returns `false` for permissions that don't exist on this platform
  /// (e.g., Android roles on iOS) or aren't available at the running OS
  /// version (e.g., `POST_NOTIFICATIONS` on Android < 33).
  Future<bool> isSupported(Permission permission);

  /// Open the system settings page for this app.
  ///
  /// Useful when a permission has been permanently denied and the user
  /// must manually re-enable it.
  Future<bool> openAppSettings();

  /// Check the current granted location accuracy level, if available.
  ///
  /// This is separate from [check] to avoid overloading [PermissionGrant]
  /// with precision semantics.
  Future<LocationAccuracyStatus> checkLocationAccuracy() async =>
      LocationAccuracyStatus.notApplicable;
}

/// Default platform implementation for platforms without a native plugin.
///
/// Returns [PermissionGrant.notApplicable] for all checks and requests so
/// unsupported platforms are explicit rather than silently treated as granted.
class _NoopSimplePermissionsPlatform extends SimplePermissionsPlatform {
  // ===========================================================================
  // v2 API
  // ===========================================================================

  @override
  Future<PermissionGrant> check(Permission permission) async {
    return PermissionGrant.notApplicable;
  }

  @override
  Future<PermissionGrant> request(Permission permission) async {
    return PermissionGrant.notApplicable;
  }

  @override
  Future<bool> isSupported(Permission permission) async => false;

  @override
  Future<bool> openAppSettings() async => false;
}
