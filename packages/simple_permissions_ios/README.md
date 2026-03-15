# simple_permissions_ios

iOS implementation for the `simple_permissions_native` federated plugin.

This package is registered automatically by `simple_permissions_native` and uses Pigeon-backed Swift handlers for:

- contacts
- camera
- microphone
- photo library
- notifications
- location
- calendar and reminders
- Bluetooth
- speech recognition
- motion activity
- HealthKit
- App Tracking Transparency

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
- `NSSpeechRecognitionUsageDescription`
- `NSBluetoothAlwaysUsageDescription`
- `NSUserTrackingUsageDescription`

HealthKit requests also need the appropriate HealthKit usage strings and entitlements.

Repository: https://github.com/simplezen/simple-permissions
