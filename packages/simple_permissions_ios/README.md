# simple_permissions_ios

iOS implementation for the `simple_permissions_native` federated plugin.

This package is registered automatically by `simple_permissions_native` and provides Pigeon-backed Swift handlers for iOS permission APIs.

Most apps should depend on `simple_permissions_native` instead of this package directly.

## Host app requirements

Add the relevant usage-description keys in your app `Info.plist` for any permissions you request (for example camera, microphone, photos, contacts, location, reminders, speech, Bluetooth, and tracking where applicable).

Repository: https://github.com/simplezen/simple-permissions
