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

/// Status predicates shared by callers that branch on [PermissionGrant]
/// without rebuilding the same switches. Used by the facade's gate
/// helpers (`ensureGranted`, `guard`) and by [PermissionResult] so the
/// definition of "satisfied" / "denied" / "terminal" lives in one place.
extension PermissionGrantStatus on PermissionGrant {
  /// Grant is usable: the caller may proceed with the gated operation.
  ///
  /// `limited` and `provisional` are treated as satisfied because both
  /// allow the core operation to run — the caller opted into a reduced
  /// capability by asking for them (iOS limited photos; iOS provisional
  /// notifications that deliver quietly).
  bool get isSatisfied =>
      this == PermissionGrant.granted ||
      this == PermissionGrant.limited ||
      this == PermissionGrant.provisional;

  /// User (or OS) said no, in any form. Mutually exclusive with
  /// [isSatisfied] and [isUnsupported].
  bool get isDenied =>
      this == PermissionGrant.denied ||
      this == PermissionGrant.permanentlyDenied ||
      this == PermissionGrant.restricted;

  /// The permission cannot be exercised on this platform / OS version.
  ///
  /// Not the same as [isDenied]: there's no user action that can change
  /// an unsupported grant. Callers should branch their feature off
  /// rather than prompt.
  bool get isUnsupported =>
      this == PermissionGrant.notApplicable ||
      this == PermissionGrant.notAvailable;

  /// Requesting this permission is a no-op: either the OS will refuse
  /// to prompt (`permanentlyDenied`, `restricted`) or the concept
  /// doesn't exist here (`notApplicable`, `notAvailable`).
  ///
  /// The facade's `ensureGranted` short-circuits on this to avoid
  /// pointless platform round-trips and misleading prompt attempts.
  bool get isTerminal =>
      this == PermissionGrant.permanentlyDenied ||
      this == PermissionGrant.restricted ||
      this == PermissionGrant.notApplicable ||
      this == PermissionGrant.notAvailable;
}
