# simple_permissions_web

Web implementation of [`simple_permissions_native`](https://pub.dev/packages/simple_permissions_native).

This package is automatically included when you depend on `simple_permissions_native` and target the web platform. You should not need to depend on it directly.

## Supported permissions

| Permission | Browser API |
|-----------|------------|
| CameraAccess | `navigator.mediaDevices.getUserMedia({video})` |
| RecordAudio | `navigator.mediaDevices.getUserMedia({audio})` |
| FineLocation / CoarseLocation | `navigator.geolocation.getCurrentPosition()` |
| PostNotifications | `Notification.requestPermission()` |

All other permission types return `PermissionGrant.notApplicable`.
