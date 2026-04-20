import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'browser_permission_state.dart';
import 'web_permissions_api_base.dart';

void _logBrowserApiError(String op, Object error) {
  if (kDebugMode) {
    debugPrint('[simple_permissions_web] $op failed: $error');
  }
}

/// Production implementation using browser APIs via `package:web`.
class BrowserPermissionsApi implements WebPermissionsApi {
  @override
  Future<String?> queryPermission(String name) async {
    try {
      final desc = _createPermissionDescriptor(name);
      final status = await web.window.navigator.permissions.query(desc).toDart;
      return status.state;
    } catch (err) {
      // Swallowed: browser returned null state (API missing, unsupported
      // descriptor name, secure-context violation, etc). Callers treat
      // null as "unknown" → notApplicable. Surface the detail for devs.
      _logBrowserApiError('permissions.query($name)', err);
      return null;
    }
  }

  @override
  Future<bool> requestCamera() async {
    try {
      final constraints = _createMediaConstraints(video: true);
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      // Stop tracks immediately — we only needed the prompt, not the stream.
      final tracks = stream.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
      return true;
    } catch (err) {
      _logBrowserApiError('getUserMedia(camera)', err);
      return false;
    }
  }

  @override
  Future<bool> requestMicrophone() async {
    try {
      final constraints = _createMediaConstraints(audio: true);
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      final tracks = stream.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
      return true;
    } catch (err) {
      _logBrowserApiError('getUserMedia(microphone)', err);
      return false;
    }
  }

  @override
  Future<bool> requestGeolocation() async {
    // Single-shot discipline: the browser contract is success XOR error, but
    // we harden against a misbehaving implementation (or a duplicated
    // callback firing) by settling the completer at most once.
    final completer = Completer<bool>();
    var settled = false;
    void settle(bool granted) {
      if (settled) return;
      settled = true;
      completer.complete(granted);
    }

    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition _) => settle(true)).toJS,
      ((web.GeolocationPositionError _) => settle(false)).toJS,
    );
    return completer.future;
  }

  @override
  Future<String> requestNotifications() async {
    try {
      final result = await web.Notification.requestPermission().toDart;
      return result.toDart;
    } catch (err) {
      _logBrowserApiError('Notification.requestPermission', err);
      return browserStateDenied;
    }
  }

  @override
  Future<bool> openAppSettings() async => false;
}

/// Creates a JS object `{name: name}` for `navigator.permissions.query()`.
///
/// `PermissionDescriptor` was removed from `package:web` 1.0, so we
/// construct the descriptor manually via JS interop.
@JS()
extension type _PermissionDescriptor._(JSObject _) implements JSObject {
  external factory _PermissionDescriptor({String name});
}

_PermissionDescriptor _createPermissionDescriptor(String name) =>
    _PermissionDescriptor(name: name);

/// Creates a JS object for `getUserMedia()` constraints.
@JS()
extension type _MediaConstraints._(JSObject _) implements JSObject {
  external factory _MediaConstraints({bool video, bool audio});
}

web.MediaStreamConstraints _createMediaConstraints({
  bool video = false,
  bool audio = false,
}) =>
    _MediaConstraints(video: video, audio: audio) as web.MediaStreamConstraints;
