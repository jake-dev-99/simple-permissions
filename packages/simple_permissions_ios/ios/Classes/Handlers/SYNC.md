# iOS/macOS Handler Sync Guide

Several iOS handlers share logic with their macOS counterparts in
`packages/simple_permissions_macos/macos/Classes/Handlers/`. When fixing bugs
or changing behavior in a handler listed below, check whether the same change
applies to the other platform.

## Shared handlers

| Handler | Sync status |
|---------|-------------|
| ContactsPermissionHandler | Near-identical (trivial formatting diff) |
| CameraPermissionHandler | Near-identical (trivial formatting diff) |
| CalendarPermissionHandler | Shared logic, differs in availability check (`iOS 17` vs `macOS 14`) |
| NotificationPermissionHandler | Identical |
| PhotoLibraryPermissionHandler | Shared logic, macOS has backward-compat for pre-11.0 |

## iOS-only handlers (no macOS equivalent)

- BluetoothPermissionHandler
- HealthPermissionHandler
- MotionPermissionHandler
- SpeechPermissionHandler
- TrackingPermissionHandler

## Handlers with divergent implementations

| Handler | Why they differ |
|---------|----------------|
| MicrophonePermissionHandler | iOS uses `AVAudioSession.recordPermission`; macOS uses `AVCaptureDevice.authorizationStatus(for: .audio)` |
| LocationPermissionHandler | iOS supports `whenInUse` vs `always` levels; macOS only requests `always` |

## Also shared

- `PermissionSupport.swift` (protocol, GrantWire enum, ensureMainThread) is
  identical across both platforms.
- `PermissionRegistry.swift` macOS is a subset of iOS.
