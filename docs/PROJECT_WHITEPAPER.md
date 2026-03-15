# Simple Permissions Technical Note

## Current state

`simple_permissions_native` is a federated Flutter plugin with a typed API built on sealed `Permission` classes.

The shipped package layout is:

- `simple_permissions_native`: app-facing facade and exports
- `simple_permissions_platform_interface`: shared types, `PermissionResult`, `Intention`, and platform contract
- `simple_permissions_android`: Android runtime, role, and system-setting support via Pigeon and Kotlin
- `simple_permissions_ios`: iOS framework-backed permission support via Pigeon and Swift
- `simple_permissions_macos`: macOS framework-backed permission support via Pigeon and Swift

Unsupported platforms return explicit `notApplicable` results rather than pretending permissions are granted.

## API model

The public API is centered on:

- `Permission` sealed classes for individual permission concepts
- `PermissionGrant` for normalized grant states
- `PermissionResult` for aggregate checks and requests
- `Intention` for convenience grouping

`Intention` presets are intentionally conservative:

- `texting` and `calling` include runtime permissions only
- default-app role acquisition is exposed through explicit role intentions

This avoids hiding major product decisions inside convenience helpers.

## Native implementation shape

Android uses a registry of handler types keyed by Dart permission types and resolves versioned permissions against the running SDK level.

iOS and macOS use identifier-based Pigeon bridges. Each Apple package now has:

- a small plugin entrypoint
- a centralized permission registry
- domain-specific Swift handler files
- a shared `PermissionSupport.swift` for wire values and handler protocol definitions

## Validation

Repository validation currently includes:

- Dart/package analysis and unit tests for the federated packages
- Apple build validation for the example app
- example-app smoke tests on Apple targets for contacts, camera, microphone, and fine location

The smoke suite is intentionally shallow. Its purpose is to confirm that the real native paths initialize, route, and complete without channel failures.
