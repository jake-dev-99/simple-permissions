part of 'permission.dart';

/// App roles — requesting to become the default handler for a category.
///
/// Roles use the Android `RoleManager` API and are conceptually different
/// from runtime permissions: the user is asked to set this app as the default
/// handler for certain functionality (SMS, dialer, browser, etc.).
///
/// On platforms without a role concept, these return [PermissionGrant.notApplicable].
sealed class AppRole extends Permission {
  const AppRole();
}

/// Request to be the default SMS/messaging app.
///
/// - **Android**: `android.app.role.SMS` via `RoleManager`
/// - **iOS**: Not applicable
class DefaultSmsApp extends AppRole {
  const DefaultSmsApp();

  @override
  String get identifier => 'default_sms_app';
}

/// Request to be the default phone/dialer app.
///
/// - **Android**: `android.app.role.DIALER` via `RoleManager`
/// - **iOS**: Not applicable
class DefaultDialerApp extends AppRole {
  const DefaultDialerApp();

  @override
  String get identifier => 'default_dialer_app';
}

/// Request to be the default browser.
///
/// - **Android**: `android.app.role.BROWSER` via `RoleManager`
/// - **iOS**: Not applicable
class DefaultBrowserApp extends AppRole {
  const DefaultBrowserApp();

  @override
  String get identifier => 'default_browser_app';
}

/// Request to be the default digital assistant.
///
/// - **Android**: `android.app.role.ASSISTANT` via `RoleManager`
/// - **iOS**: Not applicable
class DefaultAssistantApp extends AppRole {
  const DefaultAssistantApp();

  @override
  String get identifier => 'default_assistant_app';
}
