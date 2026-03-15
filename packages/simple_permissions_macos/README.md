# simple_permissions_macos

macOS implementation for the `simple_permissions_native` federated plugin.

This package is registered automatically by `simple_permissions_native` and uses Pigeon-backed Swift handlers for:

- contacts
- camera
- microphone
- photo library
- notifications
- location
- calendar and reminders

Most apps should depend on `simple_permissions_native` instead of this package directly.

## Host app requirements

Add the matching usage-description keys for the permissions you request, such as:

- `NSContactsUsageDescription`
- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSCalendarsUsageDescription`
- `NSRemindersUsageDescription`

On macOS, sandboxed apps also need matching entitlements for the resources they access, including camera, microphone, contacts, and location.

Repository: https://github.com/simplezen/simple-permissions
