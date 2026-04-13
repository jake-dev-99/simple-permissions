import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

/// Maps [Permission] runtime types to browser Permissions API name strings.
///
/// Only permissions that have a meaningful web equivalent are included.
/// Everything else resolves to [PermissionGrant.notApplicable].
const webPermissionMapping = <Type, String>{
  CameraAccess: 'camera',
  RecordAudio: 'microphone',
  FineLocation: 'geolocation',
  CoarseLocation: 'geolocation',
  PostNotifications: 'notifications',
};

/// Whether the given [Permission] type is registered for web.
bool isWebPermissionRegistered(Type permissionType) =>
    webPermissionMapping.containsKey(permissionType);

/// Returns the web permission name for the given [Permission] type,
/// or `null` if not registered.
String? webPermissionIdentifier(Type permissionType) =>
    webPermissionMapping[permissionType];
