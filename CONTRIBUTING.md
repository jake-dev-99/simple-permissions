# Contributing

## Setup

- Install Flutter (stable) and Dart SDK matching `pubspec.yaml` constraints.
- Run `flutter pub get` in each package before local development.

## Package layout

- `simple_permissions_native/` — app-facing federated facade.
- `packages/simple_permissions_platform_interface/` — cross-platform contract and types.
- `packages/simple_permissions_android/` — Android Pigeon implementation.
- `packages/simple_permissions_ios/` — iOS Pigeon + Swift implementation.
- `packages/simple_permissions_macos/` — macOS Pigeon + Swift implementation.

## Development workflow

1. Make changes in the relevant package.
2. Run `flutter analyze` in that package.
3. Run `flutter test` in that package.
4. If API surfaces changed, update README and CHANGELOG.

## Pigeon

- Android:
  - Definition: `packages/simple_permissions_android/pigeon.dart`
  - Regenerate: `cd packages/simple_permissions_android && dart run pigeon --input pigeon.dart`
- iOS:
  - Definition: `packages/simple_permissions_ios/pigeon.dart`
  - Regenerate: `cd packages/simple_permissions_ios && dart run pigeon --input pigeon.dart`
- macOS:
  - Definition: `packages/simple_permissions_macos/pigeon.dart`
  - Regenerate: `cd packages/simple_permissions_macos && dart run pigeon --input pigeon.dart`

## Pull request checklist

- [ ] `dart format --set-exit-if-changed .` passes.
- [ ] `flutter analyze` passes in all affected packages.
- [ ] `flutter test` passes in all affected packages.
- [ ] Public API/docs/changelog are updated.
- [ ] No deprecated API usage added to new code.
