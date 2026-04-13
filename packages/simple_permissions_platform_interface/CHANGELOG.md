## 1.2.0

- Made `Intention` constructor `const`-constructible from user code.
- Removed `UnmodifiableListView` wrapping from `Intention.permissions`.

## 1.1.0

- Added location accuracy API surface:
  - `LocationAccuracyStatus`
  - `SimplePermissionsPlatform.checkLocationAccuracy()`
- Expanded permission model with additional Android permission types.
- Updated and validated platform interface tests for new grant/status semantics.

## 1.0.0

- Initial stable release of the platform interface.
- Added v2 typed API based on `Permission` sealed classes.

