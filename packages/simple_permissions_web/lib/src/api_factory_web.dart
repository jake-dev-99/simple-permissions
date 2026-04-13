import 'web_permissions_api.dart';
import 'web_permissions_api_base.dart';

/// Creates the real browser-backed API implementation.
WebPermissionsApi createBrowserApi() => BrowserPermissionsApi();
