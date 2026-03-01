## 1.1.0

- Added location accuracy API:
  - `checkLocationAccuracy()`
  - `LocationAccuracyStatus` (`precise`, `reduced`, `none`, `notApplicable`, `notAvailable`)
- Enforced Android background-location sequencing on API 30+:
  - `BackgroundLocation` requests now require prior foreground location grant.
  - If requested first, the plugin returns `PermissionGrant.denied` and does not invoke runtime request.
- Added Android permission types:
  - `BodySensorsBackground`
  - `ReadVoicemail`
  - `AddVoicemail`
  - `UwbRanging`
  - `AcceptHandover`

## 1.0.0

- Initial release of `simple_permissions_native`.
- Introduced federated plugin structure with:
  - `simple_permissions_platform_interface`
  - `simple_permissions_android`
  - `simple_permissions_ios`
- Added capability-based permission APIs for cross-platform checks and requests.
- Added detailed permission result modeling for richer status reporting.
- Included iOS privacy manifest support for App Store compliance.
