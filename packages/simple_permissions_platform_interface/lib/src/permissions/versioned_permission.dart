part of 'permission.dart';

/// A permission that has OS-version-dependent variants.
///
/// Instead of manually picking between [ReadMediaImages] (API 33+) and
/// [ReadExternalStorage] (API < 33), use [VersionedPermission.images()].
/// The platform implementation resolves the correct concrete [Permission]
/// for the running device.
///
/// ```dart
/// // Automatically picks the right permission for the device's OS version
/// final result = await SimplePermissionsNative.instance.request(
///   VersionedPermission.images(),
/// );
/// ```
///
/// If you need fine-grained control, use the concrete [Permission] types
/// directly — but be aware that you're responsible for version coverage.
class VersionedPermission extends Permission {
  const VersionedPermission._({
    required this.identifier,
    required this.variants,
  });

  /// The logical identifier for this versioned permission group.
  @override
  final String identifier;

  /// Ordered list of version-specific variants, from newest to oldest.
  ///
  /// Platform implementations iterate this list and select the first
  /// variant whose version requirements match the running OS.
  final List<VersionedVariant> variants;

  // ---------------------------------------------------------------------------
  // Storage permissions — Android 33 split
  // ---------------------------------------------------------------------------

  /// Read image files — resolves to [ReadMediaImages] (API 33+) or
  /// [ReadExternalStorage] (API < 33).
  const factory VersionedPermission.images() = _VersionedImages;

  /// Read video files — resolves to [ReadMediaVideo] (API 33+) or
  /// [ReadExternalStorage] (API < 33).
  const factory VersionedPermission.video() = _VersionedVideo;

  /// Read audio files — resolves to [ReadMediaAudio] (API 33+) or
  /// [ReadExternalStorage] (API < 33).
  const factory VersionedPermission.audio() = _VersionedAudio;

  // ---------------------------------------------------------------------------
  // Bluetooth permissions — Android 31 split
  // ---------------------------------------------------------------------------

  /// Bluetooth connect — resolves to [BluetoothConnect] (API 31+) or
  /// [BluetoothLegacy] (API < 31).
  const factory VersionedPermission.bluetoothConnect() =
      _VersionedBluetoothConnect;

  /// Bluetooth scan — resolves to [BluetoothScan] (API 31+) or
  /// [BluetoothAdminLegacy] (API < 31).
  const factory VersionedPermission.bluetoothScan() = _VersionedBluetoothScan;
}

/// A single version-specific variant within a [VersionedPermission].
class VersionedVariant {
  const VersionedVariant({
    required this.permission,
    this.minApiLevel,
    this.maxApiLevel,
  });

  /// The concrete permission to use when this variant applies.
  final Permission permission;

  /// Minimum Android API level (inclusive) where this variant applies.
  /// `null` means no lower bound.
  final int? minApiLevel;

  /// Maximum Android API level (inclusive) where this variant applies.
  /// `null` means no upper bound.
  final int? maxApiLevel;
}

// =============================================================================
// Concrete implementations
// =============================================================================

class _VersionedImages extends VersionedPermission {
  const _VersionedImages()
      : super._(
          identifier: 'versioned_images',
          variants: const [
            VersionedVariant(
              permission: ReadMediaImages(),
              minApiLevel: 33,
            ),
            VersionedVariant(
              permission: ReadExternalStorage(),
              maxApiLevel: 32,
            ),
          ],
        );
}

class _VersionedVideo extends VersionedPermission {
  const _VersionedVideo()
      : super._(
          identifier: 'versioned_video',
          variants: const [
            VersionedVariant(
              permission: ReadMediaVideo(),
              minApiLevel: 33,
            ),
            VersionedVariant(
              permission: ReadExternalStorage(),
              maxApiLevel: 32,
            ),
          ],
        );
}

class _VersionedAudio extends VersionedPermission {
  const _VersionedAudio()
      : super._(
          identifier: 'versioned_audio',
          variants: const [
            VersionedVariant(
              permission: ReadMediaAudio(),
              minApiLevel: 33,
            ),
            VersionedVariant(
              permission: ReadExternalStorage(),
              maxApiLevel: 32,
            ),
          ],
        );
}

class _VersionedBluetoothConnect extends VersionedPermission {
  const _VersionedBluetoothConnect()
      : super._(
          identifier: 'versioned_bluetooth_connect',
          variants: const [
            VersionedVariant(
              permission: BluetoothConnect(),
              minApiLevel: 31,
            ),
            VersionedVariant(
              permission: BluetoothLegacy(),
              maxApiLevel: 30,
            ),
          ],
        );
}

class _VersionedBluetoothScan extends VersionedPermission {
  const _VersionedBluetoothScan()
      : super._(
          identifier: 'versioned_bluetooth_scan',
          variants: const [
            VersionedVariant(
              permission: BluetoothScan(),
              minApiLevel: 31,
            ),
            VersionedVariant(
              permission: BluetoothAdminLegacy(),
              maxApiLevel: 30,
            ),
          ],
        );
}
