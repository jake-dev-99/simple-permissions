library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

export 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

class SimplePermissionsNative {
  SimplePermissionsNative._();

  static final SimplePermissionsNative instance = SimplePermissionsNative._();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
  }

  Future<PermissionGrant> check(Permission permission) {
    return _ensureInitialized().check(permission);
  }

  Future<PermissionGrant> request(Permission permission) {
    return _ensureInitialized().request(permission);
  }

  Future<PermissionResult> checkAll(List<Permission> permissions) {
    return _ensureInitialized().checkAll(permissions);
  }

  Future<PermissionResult> requestAll(List<Permission> permissions) {
    return _ensureInitialized().requestAll(permissions);
  }

  bool isSupported(Permission permission) {
    return _ensureInitialized().isSupported(permission);
  }

  Future<bool> checkIntention(Intention intention) async {
    final result = await checkAll(intention.permissions);
    return result.isFullyGranted;
  }

  Future<bool> requestIntention(Intention intention) async {
    final result = await requestAll(intention.permissions);
    return result.isFullyGranted;
  }

  Future<PermissionResult> checkIntentionDetailed(Intention intention) {
    return checkAll(intention.permissions);
  }

  Future<PermissionResult> requestIntentionDetailed(Intention intention) {
    return requestAll(intention.permissions);
  }

  Future<bool> openAppSettings() {
    return _ensureInitialized().openAppSettings();
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
