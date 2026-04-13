import 'web_permissions_api_base.dart';

/// Stub factory used when `dart:js_interop` is not available (VM tests).
WebPermissionsApi createBrowserApi() => throw UnsupportedError(
      'BrowserPermissionsApi requires dart:js_interop (web platform only)',
    );
