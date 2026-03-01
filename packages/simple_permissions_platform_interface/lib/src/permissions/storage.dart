part of 'permission.dart';

/// Permissions related to file and media storage access.
///
/// Android's storage permission model has changed significantly across versions:
/// - API < 33: `READ_EXTERNAL_STORAGE` covers all media
/// - API 33+: Granular `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`
/// - API 34+: `READ_MEDIA_VISUAL_USER_SELECTED` for partial photo access
///
/// Use [VersionedPermission] helpers to automatically resolve the correct
/// permission for the running device.
sealed class StoragePermission extends Permission {
  const StoragePermission();
}

/// Read files from external storage (legacy, pre-API 33).
///
/// - **Android**: `android.permission.READ_EXTERNAL_STORAGE` (API < 33)
/// - **iOS**: Not applicable
///
/// Superseded by [ReadMediaImages], [ReadMediaVideo], [ReadMediaAudio] on
/// API 33+. Use [VersionedPermission.images()] etc. for automatic resolution.
class ReadExternalStorage extends StoragePermission {
  const ReadExternalStorage();

  @override
  String get identifier => 'read_external_storage';
}

/// Read image files from shared storage.
///
/// - **Android**: `android.permission.READ_MEDIA_IMAGES` (API 33+)
/// - **iOS**: `PHAuthorizationStatus` for `.readWrite`
class ReadMediaImages extends StoragePermission {
  const ReadMediaImages();

  @override
  String get identifier => 'read_media_images';
}

/// Read video files from shared storage.
///
/// - **Android**: `android.permission.READ_MEDIA_VIDEO` (API 33+)
/// - **iOS**: `PHAuthorizationStatus` for `.readWrite`
class ReadMediaVideo extends StoragePermission {
  const ReadMediaVideo();

  @override
  String get identifier => 'read_media_video';
}

/// Read audio files from shared storage.
///
/// - **Android**: `android.permission.READ_MEDIA_AUDIO` (API 33+)
/// - **iOS**: Not directly applicable (media library is separate)
class ReadMediaAudio extends StoragePermission {
  const ReadMediaAudio();

  @override
  String get identifier => 'read_media_audio';
}

/// Partial photo/video access (user-selected subset).
///
/// - **Android**: `android.permission.READ_MEDIA_VISUAL_USER_SELECTED` (API 34+)
/// - **iOS**: `PHAuthorizationStatus.limited`
class ReadMediaVisualUserSelected extends StoragePermission {
  const ReadMediaVisualUserSelected();

  @override
  String get identifier => 'read_media_visual_user_selected';
}
