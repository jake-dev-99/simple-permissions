/// Precision level of granted location access.
///
/// This is intentionally separate from [PermissionGrant] so existing
/// permission request/check semantics remain unchanged and backward compatible.
enum LocationAccuracyStatus {
  /// Full/precise location is available.
  precise,

  /// Approximate/reduced accuracy location is available.
  reduced,

  /// Location is not currently granted.
  none,

  /// Location accuracy is not meaningful on this platform.
  notApplicable,

  /// Location accuracy exists conceptually but is unavailable on this OS version.
  notAvailable,
}
