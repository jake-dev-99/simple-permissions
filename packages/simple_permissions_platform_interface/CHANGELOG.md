## 1.3.0

- Coordinated release: aligned all federated packages on 1.8.0 to match
  the `simple_permissions_native` facade. No source changes — version
  consolidation only. Fills in the gap from the previously-unpublished
  versions (1.3 — 1.7) where the facade evolved independently of the
  platform packages.
- All cross-package constraints bumped to `^1.8.0`.

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