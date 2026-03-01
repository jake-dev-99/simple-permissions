enum PermissionGrant {
  /// The permission has been granted by the user.
  granted,

  /// The permission has been denied but can be requested again.
  denied,

  /// The user selected "Don't ask again" — must go to Settings.
  permanentlyDenied,

  /// The OS restricts this permission (e.g., parental controls on iOS).
  restricted,

  /// Partial access was granted (e.g., iOS limited photo library).
  limited,

  /// This permission concept does not exist on the current platform.
  notApplicable,

  /// The permission exists on this platform but not on the running OS version.
  ///
  /// For example, `POST_NOTIFICATIONS` on Android < 33, or
  /// `AppTrackingTransparency` on iOS < 14.
  notAvailable,

  /// iOS provisional notification authorization (delivers quietly).
  provisional,
}
