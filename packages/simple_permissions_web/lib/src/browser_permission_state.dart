/// String values returned by `PermissionStatus.state` and accepted by
/// `Notification.requestPermission()`.
///
/// These come from the W3C Permissions API / Notifications spec; named
/// constants so literals don't drift across the package.
library;

/// `"granted"` — user has granted the permission.
const String browserStateGranted = 'granted';

/// `"denied"` — user has explicitly refused and won't be re-prompted.
const String browserStateDenied = 'denied';

/// `"prompt"` — no decision yet; next request will trigger a prompt.
const String browserStatePrompt = 'prompt';
