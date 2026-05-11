## 1.3.0

- Coordinated release: aligned all federated packages on 1.8.0 to match
  the `simple_permissions_native` facade. No source changes — version
  consolidation only. Fills in the gap from the previously-unpublished
  versions (1.3 — 1.7) where the facade evolved independently of the
  platform packages.
- All cross-package constraints bumped to `^1.8.0`.

## 1.2.0

- Split native iOS permission handlers into domain files with a centralized registry.
- Added Apple example build and smoke-test coverage for the federated plugin.
- Added iOS/macOS handler sync documentation.

## 1.1.0

- Added location accuracy status bridge support.
- Synced plugin and podspec metadata to `1.1.0`.
- Continued Pigeon-based typed permission bridge coverage for iOS handlers.

## 1.0.0

- Initial stable iOS implementation for the federated plugin.
- Added Swift authorization handlers wired through Pigeon host APIs.