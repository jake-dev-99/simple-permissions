# Simple Permissions Flutter Plugin

## Technical Whitepaper

**Version:** 0.0.1 (Pre-release)
**Document Date:** December 2025
**Status:** Architecture Complete, Platform Implementation Pending

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Solution Overview](#3-solution-overview)
4. [Design Philosophy & Methodology](#4-design-philosophy--methodology)
5. [Technical Architecture](#5-technical-architecture)
6. [API Design & Specification](#6-api-design--specification)
7. [Implementation Plan](#7-implementation-plan)
8. [Platform-Specific Considerations](#8-platform-specific-considerations)
9. [Security Model](#9-security-model)
10. [Testing Strategy](#10-testing-strategy)
11. [Deployment & Distribution](#11-deployment--distribution)
12. [Performance Considerations](#12-performance-considerations)
13. [Versioning & Compatibility](#13-versioning--compatibility)
14. [Future Roadmap](#14-future-roadmap)
15. [Risk Assessment](#15-risk-assessment)
16. [Appendices](#16-appendices)

---

## 1. Executive Summary

**Simple Permissions** is a Flutter plugin designed to simplify Android permission management by introducing an **intent-based abstraction layer**. Rather than requiring developers to understand and manage individual Android permission strings, the plugin exposes high-level "intentions" that map to coherent permission groups required for specific user workflows.

### Key Value Propositions

- **Developer Experience**: Reduces cognitive load by abstracting raw permission strings into meaningful intentions
- **Android Role Integration**: First-class support for Android's Role API (introduced in Android Q/10)
- **Type Safety**: Dart enum-based API prevents invalid permission requests at compile time
- **Federated Architecture**: Extensible platform interface allows custom implementations and testing

### Current Project State

The Dart/Flutter layer is architecturally complete with:
- ✅ Public API design (`SimplePermissions` class)
- ✅ Platform interface abstraction (`SimplePermissionsPlatform`)
- ✅ Method channel scaffold (`MethodChannelSimplePermissions`)
- ✅ Intent-to-permission mapping (`Intention` enum)
- ✅ Unit test infrastructure with mocking patterns
- ⏳ **Pending**: Native Android (Kotlin/Java) implementation
- ⏳ **Pending**: Native iOS (Swift/Objective-C) implementation

---

## 2. Problem Statement

### 2.1 The Android Permission Complexity

Android's permission system has evolved significantly across versions, creating substantial complexity for developers:

| Android Version | Permission Changes |
|-----------------|-------------------|
| 6.0 (M) | Runtime permissions introduced |
| 8.0 (O) | Permission groups behavior changes |
| 10 (Q) | Role API introduced for default apps |
| 11 (R) | One-time permissions, auto-reset |
| 12 (S) | Approximate location, Bluetooth permissions |
| 13 (T) | Granular media permissions |
| 14 (U) | Photo picker, partial media access |

### 2.2 Specific Challenges Addressed

1. **Permission String Fragmentation**: Developers must know exact permission strings (e.g., `android.permission.SEND_SMS`) which vary in format and are error-prone

2. **Permission Grouping Logic**: A single user intent (e.g., "handle SMS") requires multiple permissions that must be requested coherently:
   ```
   SEND_SMS, READ_SMS, RECEIVE_SMS, WRITE_SMS, RECEIVE_WAP_PUSH, RECEIVE_MMS
   ```

3. **Role API Complexity**: Default app roles (SMS handler, Dialer) require completely different request flows than standard runtime permissions

4. **Cross-Platform Abstraction**: Flutter developers need consistent APIs that work across Android and iOS despite fundamentally different permission models

5. **Permission Rationale UX**: Best practices require explaining why permissions are needed, but this is often implemented inconsistently

### 2.3 Target User Personas

| Persona | Pain Point | Solution Benefit |
|---------|------------|------------------|
| Flutter Developer (Junior) | Unfamiliar with Android permission system | Intent-based API hides complexity |
| Flutter Developer (Senior) | Boilerplate code for permission flows | Consolidated, tested implementation |
| App Architect | Inconsistent permission handling across team | Standardized pattern enforcement |
| QA Engineer | Difficulty testing permission states | Mockable platform interface |

---

## 3. Solution Overview

### 3.1 Intent-Based Abstraction Model

The core innovation is mapping **user intents** to **permission requirements**:

```
┌─────────────────────────────────────────────────────────────────┐
│                      APPLICATION LAYER                          │
│                                                                 │
│   "I want to send/receive text messages"                       │
│                         │                                       │
│                         ▼                                       │
│              ┌─────────────────────┐                           │
│              │  Intention.texting  │                           │
│              └─────────────────────┘                           │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SIMPLE_PERMISSIONS LAYER                      │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  Intention.texting.role = 'android.app.role.SMS'        │  │
│   │  Intention.texting.permissions = [                       │  │
│   │    'android.permission.SEND_SMS',                        │  │
│   │    'android.permission.READ_SMS',                        │  │
│   │    'android.permission.RECEIVE_SMS',                     │  │
│   │    'android.permission.WRITE_SMS',                       │  │
│   │    'android.permission.RECEIVE_WAP_PUSH',                │  │
│   │    'android.permission.RECEIVE_MMS'                      │  │
│   │  ]                                                       │  │
│   └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     PLATFORM LAYER                              │
│                                                                 │
│   Android: RoleManager.requestRole() + ActivityCompat          │
│   iOS: (Mapped to equivalent capabilities or no-op)            │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Supported Intentions (v0.0.1)

| Intention | Role Required | Permissions | Use Case |
|-----------|---------------|-------------|----------|
| `texting` | `android.app.role.SMS` | 6 SMS-related permissions | SMS/MMS apps, messaging features |
| `calling` | `android.app.role.DIALER` | READ_PHONE_STATE, READ_PHONE_NUMBERS | Dialer apps, call features |
| `contacts` | None | WRITE_CONTACTS, READ_CONTACTS, MANAGE_OWN_CALLS | Contact management |
| `device` | None | READ_DEVICE_CONFIG | Device information access |
| `fileAccess` | None | 4 storage/media permissions | File browsers, media apps |

### 3.3 Role vs. Permission-Only Intentions

```dart
// Role-based intentions (requires becoming default app)
Intention.texting.role   // Returns 'android.app.role.SMS'
Intention.calling.role   // Returns 'android.app.role.DIALER'

// Permission-only intentions
Intention.contacts.role  // Returns null
Intention.device.role    // Returns null
Intention.fileAccess.role // Returns null
```

**Implication**: Role-based intentions require the Android `RoleManager` API flow, which prompts the user to set the app as the default handler. Permission-only intentions use standard `ActivityCompat.requestPermissions()`.

---

## 4. Design Philosophy & Methodology

### 4.1 Guiding Principles

1. **Intention Over Implementation**
   - API expresses *what* the developer wants to accomplish, not *how*
   - Platform details are implementation concerns, not API concerns

2. **Fail-Safe Defaults**
   - Enum-based API prevents requesting invalid permissions
   - Compile-time type checking over runtime validation

3. **Testability First**
   - Platform interface pattern enables complete mocking
   - No static dependencies that impede testing

4. **Progressive Disclosure**
   - Simple API for common cases
   - Access to underlying permission lists for advanced use cases

### 4.2 Federated Plugin Architecture

The plugin follows Flutter's **federated plugin pattern**, which separates:

```
┌─────────────────────────────────────────────────────────────────┐
│                    App-Facing Package                           │
│                   (simple_permissions)                          │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  SimplePermissions                                       │  │
│   │  - getPlatformVersion()                                  │  │
│   │  - requestPermission(Intention)  [future]                │  │
│   │  - checkPermission(Intention)    [future]                │  │
│   └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                          │
                          │ delegates to
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                Platform Interface Package                        │
│          (simple_permissions_platform_interface)                 │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  SimplePermissionsPlatform (abstract)                    │  │
│   │  - Extends PlatformInterface                             │  │
│   │  - Token-based verification                              │  │
│   │  - Singleton instance pattern                            │  │
│   └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                          │
                          │ implemented by
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Platform Implementation Packages                    │
│                                                                 │
│   ┌──────────────────────┐    ┌───────────────────────────┐   │
│   │  MethodChannel       │    │  simple_permissions_android│   │
│   │  (default fallback)  │    │  (future native impl)     │   │
│   └──────────────────────┘    └───────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 Why Federated?

| Benefit | Explanation |
|---------|-------------|
| **Platform Isolation** | Android-specific code doesn't pollute iOS builds and vice versa |
| **Independent Versioning** | Platform implementations can be updated without Dart API changes |
| **Custom Implementations** | Enterprise users can swap in proprietary implementations |
| **Testability** | Mock implementations can be injected via `instance` setter |
| **Web/Desktop Expansion** | New platforms can be added without modifying core package |

### 4.4 Token-Based Platform Verification

```dart
abstract class SimplePermissionsPlatform extends PlatformInterface {
  SimplePermissionsPlatform() : super(token: _token);

  static final Object _token = Object();

  static set instance(SimplePermissionsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }
}
```

This pattern from `plugin_platform_interface` ensures:
- Only legitimate implementations can register
- Prevents accidental overwrites
- Enforces inheritance from `PlatformInterface`

---

## 5. Technical Architecture

### 5.1 Package Structure

```
simple_permissions/
├── lib/
│   ├── simple_permissions.dart              # Public API exports
│   │   ├── class SimplePermissions          # Main entry point
│   │   └── enum Intention                   # Intent definitions
│   │
│   ├── simple_permissions_platform_interface.dart
│   │   └── abstract class SimplePermissionsPlatform
│   │
│   └── simple_permissions_method_channel.dart
│       └── class MethodChannelSimplePermissions
│
├── test/
│   ├── simple_permissions_test.dart         # Public API tests
│   └── simple_permissions_method_channel_test.dart
│
├── example/
│   ├── lib/main.dart                        # Demo application
│   └── integration_test/
│       └── plugin_integration_test.dart     # Device tests
│
├── android/                                 # [TO BE GENERATED]
│   ├── src/main/kotlin/                     # Kotlin implementation
│   └── build.gradle                         # Android build config
│
└── ios/                                     # [TO BE GENERATED]
    ├── Classes/                             # Swift implementation
    └── simple_permissions.podspec           # CocoaPods config
```

### 5.2 Class Diagram

```
┌───────────────────────────────────────────────────────────────────┐
│                                                                   │
│  ┌─────────────────────┐         ┌──────────────────────────┐   │
│  │   SimplePermissions │         │       <<enum>>           │   │
│  ├─────────────────────┤         │       Intention          │   │
│  │                     │         ├──────────────────────────┤   │
│  │ + getPlatformVersion│         │ texting                  │   │
│  │ + requestPermission │         │ calling                  │   │
│  │ + checkPermission   │         │ contacts                 │   │
│  │                     │         │ device                   │   │
│  └──────────┬──────────┘         │ fileAccess               │   │
│             │                    ├──────────────────────────┤   │
│             │ uses               │ + role: String?          │   │
│             ▼                    │ + permissions: List<String>│  │
│  ┌─────────────────────────┐     └──────────────────────────┘   │
│  │<<abstract>>             │                                     │
│  │SimplePermissionsPlatform│                                     │
│  ├─────────────────────────┤                                     │
│  │ - _token: Object        │                                     │
│  │ - _instance: Platform   │                                     │
│  ├─────────────────────────┤                                     │
│  │ + instance: Platform    │                                     │
│  │ + getPlatformVersion()  │                                     │
│  └──────────┬──────────────┘                                     │
│             │                                                     │
│             │ extends                                             │
│             ▼                                                     │
│  ┌──────────────────────────────┐                                │
│  │MethodChannelSimplePermissions│                                │
│  ├──────────────────────────────┤                                │
│  │ + methodChannel: MethodChannel│                               │
│  ├──────────────────────────────┤                                │
│  │ + getPlatformVersion()       │                                │
│  └──────────────────────────────┘                                │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

### 5.3 Method Channel Protocol

**Channel Name**: `'simple_permissions'`

**Current Methods**:
| Method | Arguments | Return | Description |
|--------|-----------|--------|-------------|
| `getPlatformVersion` | None | `String?` | Returns platform OS version |

**Planned Methods**:
| Method | Arguments | Return | Description |
|--------|-----------|--------|-------------|
| `requestPermission` | `{intention: String, permissions: List<String>, role: String?}` | `Map<String, dynamic>` | Request permissions for intention |
| `checkPermission` | `{permissions: List<String>}` | `Map<String, bool>` | Check current permission states |
| `requestRole` | `{role: String}` | `bool` | Request default app role |
| `isRoleHeld` | `{role: String}` | `bool` | Check if app holds role |
| `openSettings` | None | `void` | Open app permission settings |

### 5.4 Data Flow Sequence

```
┌──────────┐     ┌─────────────────┐     ┌────────────────┐     ┌──────────────┐
│   App    │     │SimplePermissions│     │ MethodChannel  │     │ Native Code  │
└────┬─────┘     └───────┬─────────┘     └───────┬────────┘     └──────┬───────┘
     │                   │                       │                      │
     │ requestPermission │                       │                      │
     │ (Intention.texting)                       │                      │
     │──────────────────>│                       │                      │
     │                   │                       │                      │
     │                   │ invokeMethod          │                      │
     │                   │ 'requestPermission'   │                      │
     │                   │ {role: '...SMS',      │                      │
     │                   │  permissions: [...]}  │                      │
     │                   │──────────────────────>│                      │
     │                   │                       │                      │
     │                   │                       │  MethodCallHandler   │
     │                   │                       │─────────────────────>│
     │                   │                       │                      │
     │                   │                       │      [Role Check]    │
     │                   │                       │      [Permission     │
     │                   │                       │       Request]       │
     │                   │                       │      [Activity       │
     │                   │                       │       Result]        │
     │                   │                       │                      │
     │                   │                       │<─────────────────────│
     │                   │                       │  {granted: [...],    │
     │                   │                       │   denied: [...]}     │
     │                   │<──────────────────────│                      │
     │                   │                       │                      │
     │<──────────────────│                       │                      │
     │ PermissionResult  │                       │                      │
     │                   │                       │                      │
```

---

## 6. API Design & Specification

### 6.1 Current Public API

```dart
// simple_permissions.dart

/// Main entry point for permission operations
class SimplePermissions {
  /// Returns the platform operating system version
  Future<String?> getPlatformVersion() {
    return SimplePermissionsPlatform.instance.getPlatformVersion();
  }
}

/// Represents user intentions requiring permissions
enum Intention {
  texting,
  calling,
  contacts,
  device,
  fileAccess;

  /// Android role identifier, null if no role required
  String? get role { ... }

  /// List of Android permission strings for this intention
  List<String> get permissions { ... }
}
```

### 6.2 Planned API Extensions

```dart
/// Permission request result
class PermissionResult {
  final Intention intention;
  final Map<String, PermissionStatus> permissions;
  final bool roleGranted;
  final bool allGranted;

  bool get isFullyGranted => allGranted && (intention.role == null || roleGranted);
}

/// Individual permission status
enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,  // "Don't ask again" selected
  restricted,          // iOS parental controls, MDM
  limited,             // iOS 14+ limited photo access
  provisional,         // iOS provisional notifications
}

/// Extended SimplePermissions API
class SimplePermissions {
  /// Request permissions for an intention
  Future<PermissionResult> request(Intention intention);

  /// Check current permission status without requesting
  Future<PermissionResult> check(Intention intention);

  /// Check if the app holds a specific role
  Future<bool> isRoleHeld(String role);

  /// Open system settings for this app
  Future<void> openSettings();

  /// Check if permission rationale should be shown
  Future<bool> shouldShowRationale(Intention intention);
}
```

### 6.3 Usage Examples

**Basic Permission Request**:
```dart
final permissions = SimplePermissions();

// Request texting permissions
final result = await permissions.request(Intention.texting);

if (result.isFullyGranted) {
  // All permissions granted, proceed with SMS functionality
  sendSms();
} else if (result.permissions.values.any((s) => s == PermissionStatus.permanentlyDenied)) {
  // User selected "Don't ask again", show settings prompt
  showSettingsDialog(onConfirm: () => permissions.openSettings());
} else {
  // Permissions denied but can be re-requested
  showPermissionRationale();
}
```

**Checking Without Requesting**:
```dart
// Pre-check before showing SMS-related UI
final status = await permissions.check(Intention.texting);

if (status.isFullyGranted) {
  showSmsComposer();
} else {
  showSmsFeatureTeaser(onTap: () => requestSmsPermissions());
}
```

**Accessing Raw Permissions**:
```dart
// For advanced use cases, access underlying permission lists
print(Intention.texting.permissions);
// ['android.permission.SEND_SMS', 'android.permission.READ_SMS', ...]

print(Intention.texting.role);
// 'android.app.role.SMS'
```

---

## 7. Implementation Plan

### 7.1 Phase Overview

```
Phase 1: Scaffold (✅ COMPLETE)
├── Dart API design
├── Platform interface
├── Method channel scaffold
├── Unit test infrastructure
└── Example app skeleton

Phase 2: Android Implementation (🔄 IN PROGRESS)
├── Generate platform support
├── Kotlin plugin class
├── Permission request flow
├── Role request flow
└── Activity result handling

Phase 3: iOS Implementation (📋 PLANNED)
├── Swift plugin class
├── Info.plist mapping
├── Permission request flow
└── Platform-specific adaptations

Phase 4: Polish & Release (📋 PLANNED)
├── API refinement
├── Documentation
├── pub.dev publishing
└── CI/CD setup
```

### 7.2 Phase 2: Android Implementation Details

#### 7.2.1 Generate Platform Support

```bash
flutter create -t plugin --platforms android .
```

This generates:
- `android/src/main/kotlin/.../SimplePermissionsPlugin.kt`
- `android/build.gradle`
- `android/settings.gradle`

#### 7.2.2 Native Kotlin Implementation

```kotlin
// SimplePermissionsPlugin.kt (planned structure)

class SimplePermissionsPlugin: FlutterPlugin, MethodCallHandler,
    ActivityAware, PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: MethodChannel.Result? = null

    // Permission request codes
    companion object {
        const val PERMISSION_REQUEST_CODE = 100
        const val ROLE_REQUEST_CODE = 101
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "requestPermission" -> {
                val permissions = call.argument<List<String>>("permissions")
                val role = call.argument<String?>("role")
                requestPermissions(permissions, role, result)
            }
            "checkPermission" -> {
                val permissions = call.argument<List<String>>("permissions")
                checkPermissions(permissions, result)
            }
            "requestRole" -> {
                val role = call.argument<String>("role")
                requestRole(role, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestPermissions(
        permissions: List<String>?,
        role: String?,
        result: Result
    ) {
        // 1. Check if role is required and not held
        // 2. Request role first if needed
        // 3. Request runtime permissions
        // 4. Return aggregated result
    }

    private fun requestRole(role: String?, result: Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && role != null) {
            val roleManager = activity?.getSystemService(RoleManager::class.java)
            if (roleManager?.isRoleAvailable(role) == true) {
                val intent = roleManager.createRequestRoleIntent(role)
                pendingResult = result
                activity?.startActivityForResult(intent, ROLE_REQUEST_CODE)
                return
            }
        }
        result.success(false)
    }
}
```

#### 7.2.3 AndroidManifest.xml Requirements

The example app (and consuming apps) must declare required permissions:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Texting intention -->
    <uses-permission android:name="android.permission.SEND_SMS"/>
    <uses-permission android:name="android.permission.READ_SMS"/>
    <uses-permission android:name="android.permission.RECEIVE_SMS"/>
    <uses-permission android:name="android.permission.RECEIVE_MMS"/>
    <uses-permission android:name="android.permission.RECEIVE_WAP_PUSH"/>

    <!-- Calling intention -->
    <uses-permission android:name="android.permission.READ_PHONE_STATE"/>
    <uses-permission android:name="android.permission.READ_PHONE_NUMBERS"/>

    <!-- Contacts intention -->
    <uses-permission android:name="android.permission.READ_CONTACTS"/>
    <uses-permission android:name="android.permission.WRITE_CONTACTS"/>
    <uses-permission android:name="android.permission.MANAGE_OWN_CALLS"/>

    <!-- File access intention -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>

    <!-- For role-based permissions, declare as default handler -->
    <application>
        <!-- SMS app declaration (if using texting intention with role) -->
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <action android:name="android.intent.action.SENDTO"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:scheme="sms"/>
                <data android:scheme="smsto"/>
                <data android:scheme="mms"/>
                <data android:scheme="mmsto"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### 7.3 Phase 3: iOS Implementation Details

#### 7.3.1 Permission Mapping Strategy

iOS has a fundamentally different permission model. The mapping strategy:

| Intention | iOS Equivalent | Framework |
|-----------|---------------|-----------|
| `texting` | MessageUI (no permission needed for compose), Messages Extension | MessageUI |
| `calling` | CallKit permissions | CallKit |
| `contacts` | CNContactStore authorization | Contacts |
| `device` | No direct equivalent | N/A |
| `fileAccess` | PHPhotoLibrary, UIDocumentPicker | Photos, UIKit |

#### 7.3.2 Info.plist Keys

```xml
<!-- Contacts -->
<key>NSContactsUsageDescription</key>
<string>Access contacts to...</string>

<!-- Photos -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Access photos to...</string>

<!-- Microphone (for calls) -->
<key>NSMicrophoneUsageDescription</key>
<string>Access microphone for calls...</string>
```

#### 7.3.3 Swift Plugin Structure

```swift
// SimplePermissionsPlugin.swift (planned structure)

import Flutter
import UIKit
import Contacts
import Photos

public class SimplePermissionsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "simple_permissions",
            binaryMessenger: registrar.messenger()
        )
        let instance = SimplePermissionsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "requestPermission":
            handleRequestPermission(call: call, result: result)
        case "checkPermission":
            handleCheckPermission(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleRequestPermission(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let intention = args["intention"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
            return
        }

        switch intention {
        case "contacts":
            requestContactsPermission(result: result)
        case "fileAccess":
            requestPhotosPermission(result: result)
        default:
            // Return success for intentions that don't require iOS permissions
            result(["granted": true])
        }
    }
}
```

---

## 8. Platform-Specific Considerations

### 8.1 Android Specifics

#### 8.1.1 API Level Requirements

| Feature | Minimum API | Notes |
|---------|-------------|-------|
| Runtime Permissions | 23 (M) | Core requirement |
| Role API | 29 (Q) | Optional, graceful fallback |
| Granular Media | 33 (T) | READ_MEDIA_* permissions |
| Photo Picker | 34 (U) | Alternative to storage permissions |

#### 8.1.2 Role API Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Role Request Flow                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Check API Level >= 29 (Q)                                   │
│     └─ If lower: Skip role, request permissions only            │
│                                                                 │
│  2. Check if role is available                                  │
│     └─ RoleManager.isRoleAvailable(role)                        │
│                                                                 │
│  3. Check if role is already held                               │
│     └─ RoleManager.isRoleHeld(role)                             │
│     └─ If held: Skip to permission request                      │
│                                                                 │
│  4. Create role request intent                                  │
│     └─ RoleManager.createRequestRoleIntent(role)                │
│                                                                 │
│  5. Start activity for result                                   │
│     └─ Activity.startActivityForResult(intent, requestCode)     │
│                                                                 │
│  6. Handle result in onActivityResult                           │
│     └─ RESULT_OK: Proceed to permissions                        │
│     └─ RESULT_CANCELED: Role denied, report partial             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 8.1.3 Handling "Don't Ask Again"

```kotlin
// Check if rationale should be shown
fun shouldShowRationale(permission: String): Boolean {
    return activity?.let {
        ActivityCompat.shouldShowRequestPermissionRationale(it, permission)
    } ?: false
}

// After denial, check if permanently denied
fun isPermanentlyDenied(permission: String): Boolean {
    val notGranted = ContextCompat.checkSelfPermission(context, permission) != GRANTED
    val noRationale = !shouldShowRationale(permission)
    return notGranted && noRationale
}
```

### 8.2 iOS Specifics

#### 8.2.1 Authorization Status Mapping

```swift
// CNAuthorizationStatus -> PermissionStatus
extension CNAuthorizationStatus {
    var toPermissionStatus: String {
        switch self {
        case .authorized: return "granted"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "denied"
        }
    }
}

// PHAuthorizationStatus -> PermissionStatus (iOS 14+)
extension PHAuthorizationStatus {
    var toPermissionStatus: String {
        switch self {
        case .authorized: return "granted"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        case .limited: return "limited"  // iOS 14+ partial access
        @unknown default: return "denied"
        }
    }
}
```

#### 8.2.2 iOS Permission Request Behavior

| Behavior | Description |
|----------|-------------|
| One-time prompt | iOS only shows permission prompt once per permission type |
| Settings redirect | After denial, must redirect to Settings app |
| Privacy strings required | App crashes without Info.plist usage descriptions |
| Background modes | Some permissions require background mode capabilities |

### 8.3 Cross-Platform Considerations

#### 8.3.1 Intention Compatibility Matrix

| Intention | Android | iOS | Web | Desktop |
|-----------|---------|-----|-----|---------|
| `texting` | Full | Limited* | N/A | N/A |
| `calling` | Full | Full | N/A | N/A |
| `contacts` | Full | Full | N/A | Limited |
| `device` | Full | N/A | N/A | N/A |
| `fileAccess` | Full | Full | Limited | Full |

*iOS texting doesn't require permissions for compose-only; requires extension for receiving

#### 8.3.2 Graceful Degradation Strategy

```dart
Future<PermissionResult> request(Intention intention) async {
  if (Platform.isAndroid) {
    return _requestAndroid(intention);
  } else if (Platform.isIOS) {
    return _requestIOS(intention);
  } else {
    // Unsupported platform - return "granted" to not block functionality
    // Document that permissions are not enforced on this platform
    return PermissionResult(
      intention: intention,
      permissions: {for (var p in intention.permissions) p: PermissionStatus.granted},
      roleGranted: true,
      allGranted: true,
    );
  }
}
```

---

## 9. Security Model

### 9.1 Principle of Least Privilege

The plugin is designed to request only the permissions necessary for the declared intention:

```
┌─────────────────────────────────────────────────────────────────┐
│            Permission Scope by Intention                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Intention.contacts                                             │
│  └─ Only requests: READ_CONTACTS, WRITE_CONTACTS,               │
│                    MANAGE_OWN_CALLS                             │
│  └─ Does NOT request: SMS, Phone, Storage permissions           │
│                                                                 │
│  Intention.fileAccess                                           │
│  └─ Only requests: Storage and Media permissions                │
│  └─ Does NOT request: Contacts, SMS, Phone permissions          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 9.2 Permission Transparency

```dart
// Developers can inspect exactly what will be requested
void auditPermissions() {
  for (final intention in Intention.values) {
    print('${intention.name}:');
    print('  Role: ${intention.role ?? "none"}');
    print('  Permissions: ${intention.permissions.join(", ")}');
  }
}
```

### 9.3 No Data Collection

The plugin:
- Does NOT collect or transmit permission status
- Does NOT include analytics or telemetry
- Does NOT store permission history
- Operates entirely on-device

### 9.4 Secure Platform Communication

```dart
// Method channel communication is type-safe and validated
@override
Future<String?> getPlatformVersion() async {
  // invokeMethod validates the return type
  final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
  return version;
}
```

---

## 10. Testing Strategy

### 10.1 Test Pyramid

```
                    ┌───────────┐
                   │ E2E Tests  │  Integration tests on real devices
                  │  (Manual)   │  - Permission dialogs
                 └─────────────┘   - Role requests
                       │
              ┌────────────────┐
             │ Integration     │  Automated device tests
            │  Tests           │  - example/integration_test/
           └──────────────────┘   - Real platform APIs
                   │
        ┌─────────────────────┐
       │ Unit Tests           │  Mocked platform interface
      │                       │  - test/simple_permissions_test.dart
     │                        │  - test/simple_permissions_method_channel_test.dart
    └─────────────────────────┘
```

### 10.2 Unit Testing Patterns

#### 10.2.1 Mocking the Platform Interface

```dart
// test/simple_permissions_test.dart

class MockSimplePermissionsPlatform
    with MockPlatformInterfaceMixin
    implements SimplePermissionsPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  // Add mocks for new methods
  @override
  Future<Map<String, dynamic>> requestPermission(Map<String, dynamic> args) {
    return Future.value({
      'granted': ['android.permission.READ_CONTACTS'],
      'denied': [],
    });
  }
}

void main() {
  test('getPlatformVersion returns mock value', () async {
    // Arrange
    final plugin = SimplePermissions();
    final mock = MockSimplePermissionsPlatform();
    SimplePermissionsPlatform.instance = mock;

    // Act
    final version = await plugin.getPlatformVersion();

    // Assert
    expect(version, '42');
  });
}
```

#### 10.2.2 Method Channel Testing

```dart
// test/simple_permissions_method_channel_test.dart

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelSimplePermissions platform = MethodChannelSimplePermissions();
  const MethodChannel channel = MethodChannel('simple_permissions');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getPlatformVersion':
          return '42';
        case 'requestPermission':
          return {'granted': true};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
```

### 10.3 Integration Testing

```dart
// example/integration_test/plugin_integration_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getPlatformVersion returns non-empty string', (tester) async {
    final plugin = SimplePermissions();
    final version = await plugin.getPlatformVersion();
    expect(version?.isNotEmpty, true);
  });

  testWidgets('check contacts permission status', (tester) async {
    final plugin = SimplePermissions();
    final result = await plugin.check(Intention.contacts);
    // Should return a valid status, regardless of granted/denied
    expect(result.permissions.isNotEmpty, true);
  });
}
```

### 10.4 Manual Testing Checklist

| Scenario | Android | iOS |
|----------|---------|-----|
| First-time permission request | ☐ | ☐ |
| Permission already granted | ☐ | ☐ |
| Permission denied | ☐ | ☐ |
| "Don't ask again" selected | ☐ | N/A |
| Open settings after denial | ☐ | ☐ |
| Role request (SMS) | ☐ | N/A |
| Role request (Dialer) | ☐ | N/A |
| API level < 29 (no roles) | ☐ | N/A |
| iOS 14+ limited photo access | N/A | ☐ |

### 10.5 Test Commands

```bash
# Run all unit tests
flutter test

# Run unit tests with coverage
flutter test --coverage

# Run integration tests on connected device
cd example
flutter test integration_test/

# Run integration tests on specific device
flutter test integration_test/ -d <device_id>

# Run tests with verbose output
flutter test --reporter expanded
```

---

## 11. Deployment & Distribution

### 11.1 pub.dev Publishing

#### 11.1.1 Pre-publication Checklist

```bash
# 1. Validate pubspec.yaml
flutter pub publish --dry-run

# 2. Run analyzer
flutter analyze

# 3. Format code
dart format lib test

# 4. Run all tests
flutter test

# 5. Update CHANGELOG.md
# 6. Update version in pubspec.yaml
# 7. Commit and tag release
git tag v0.0.1
git push origin v0.0.1

# 8. Publish
flutter pub publish
```

#### 11.1.2 pubspec.yaml for Publishing

```yaml
name: simple_permissions
description: >
  A Flutter plugin for simplified Android permission management using
  an intent-based abstraction. Map user intentions to permission groups
  with automatic Android Role API support.
version: 0.0.1
homepage: https://github.com/username/simple_permissions
repository: https://github.com/username/simple_permissions
issue_tracker: https://github.com/username/simple_permissions/issues
documentation: https://github.com/username/simple_permissions/wiki

environment:
  sdk: ^3.7.2
  flutter: '>=3.3.0'

dependencies:
  flutter:
    sdk: flutter
  plugin_platform_interface: ^2.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  plugin:
    platforms:
      android:
        package: com.example.simple_permissions
        pluginClass: SimplePermissionsPlugin
      ios:
        pluginClass: SimplePermissionsPlugin

topics:
  - permissions
  - android
  - plugin

screenshots:
  - description: Permission request flow
    path: screenshots/request_flow.png
```

### 11.2 Versioning Strategy

Following [Semantic Versioning](https://semver.org/):

| Version | Change Type | Examples |
|---------|-------------|----------|
| 0.0.x | Pre-release development | Bug fixes, documentation |
| 0.x.0 | API additions (pre-1.0) | New intentions, methods |
| 1.0.0 | Stable release | Production-ready |
| 1.x.0 | Backward-compatible additions | New intentions |
| 1.0.x | Bug fixes | Fixes without API changes |
| 2.0.0 | Breaking changes | API redesign |

### 11.3 CI/CD Pipeline (GitHub Actions)

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      - run: flutter pub get
      - run: flutter analyze
      - run: dart format --set-exit-if-changed lib test

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
        with:
          files: coverage/lcov.info

  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'
      - run: |
          cd example
          flutter build apk --debug

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: |
          cd example
          flutter build ios --no-codesign
```

### 11.4 Release Process

```
1. Development Complete
   └─ All tests passing
   └─ Documentation updated
   └─ CHANGELOG.md updated

2. Version Bump
   └─ Update pubspec.yaml version
   └─ Update CHANGELOG.md with date
   └─ Commit: "chore: release v0.0.1"

3. Create Release
   └─ git tag v0.0.1
   └─ git push origin v0.0.1
   └─ GitHub Release with notes

4. Publish
   └─ flutter pub publish
   └─ Verify on pub.dev

5. Announce
   └─ Social media
   └─ Flutter community
```

---

## 12. Performance Considerations

### 12.1 Startup Impact

The plugin is designed for minimal startup impact:

```dart
// Lazy initialization - no work done until first use
class SimplePermissions {
  // No constructor initialization
  // Platform instance is pre-created but methods are lazy

  Future<String?> getPlatformVersion() {
    // Work only happens when called
    return SimplePermissionsPlatform.instance.getPlatformVersion();
  }
}
```

### 12.2 Method Channel Overhead

| Operation | Typical Latency | Notes |
|-----------|-----------------|-------|
| `getPlatformVersion` | <5ms | Simple string return |
| `checkPermission` | <10ms | Context lookup only |
| `requestPermission` | 0-5000ms | Depends on user interaction |
| `requestRole` | 0-10000ms | System dialog, user decision |

### 12.3 Memory Footprint

```
┌─────────────────────────────────────────────────────────────────┐
│ Component               │ Memory Impact                         │
├─────────────────────────────────────────────────────────────────┤
│ Dart classes            │ ~2KB (negligible)                     │
│ Method channel          │ ~1KB (Flutter overhead)               │
│ Intention enum          │ ~1KB (static strings)                 │
│ Android native code     │ ~50KB (Kotlin runtime)                │
│ iOS native code         │ ~30KB (Swift runtime)                 │
└─────────────────────────────────────────────────────────────────┘
Total: ~80-85KB increase in app size
```

### 12.4 Best Practices for Consumers

```dart
// ✅ DO: Check permissions once, cache result
class PermissionManager {
  PermissionResult? _contactsStatus;

  Future<bool> get canAccessContacts async {
    _contactsStatus ??= await _permissions.check(Intention.contacts);
    return _contactsStatus!.isFullyGranted;
  }
}

// ❌ DON'T: Check permissions repeatedly in build methods
Widget build(BuildContext context) {
  // This causes unnecessary platform calls every frame
  final status = await permissions.check(Intention.contacts); // BAD
}
```

---

## 13. Versioning & Compatibility

### 13.1 Flutter SDK Compatibility

| Plugin Version | Flutter Version | Dart Version |
|----------------|-----------------|--------------|
| 0.0.1 | >=3.3.0 | >=3.7.2 |

### 13.2 Android Compatibility

| Plugin Version | Min SDK | Target SDK | Compile SDK |
|----------------|---------|------------|-------------|
| 0.0.1 | 21 | 34 | 34 |

### 13.3 iOS Compatibility

| Plugin Version | Min iOS | Deployment Target |
|----------------|---------|-------------------|
| 0.0.1 | 12.0 | 12.0 |

### 13.4 Dependency Versions

```yaml
# Pinned dependencies for reproducibility
dependencies:
  flutter:
    sdk: flutter
  plugin_platform_interface: ^2.0.2

# pubspec.lock ensures consistent versions
# Version: 2.1.8 of plugin_platform_interface
```

### 13.5 Breaking Change Policy

| Change Type | Handling |
|-------------|----------|
| New intentions | Non-breaking, minor version bump |
| New methods | Non-breaking, minor version bump |
| Permission string changes | Breaking (tied to Android releases) |
| API signature changes | Breaking, major version bump |
| Enum value removal | Breaking, major version bump |

---

## 14. Future Roadmap

### 14.1 Short-term (v0.1.0 - v0.5.0)

| Feature | Priority | Status |
|---------|----------|--------|
| Android native implementation | P0 | 🔄 In Progress |
| iOS native implementation | P0 | 📋 Planned |
| `request()` and `check()` methods | P0 | 📋 Planned |
| `openSettings()` method | P1 | 📋 Planned |
| `shouldShowRationale()` method | P1 | 📋 Planned |
| pub.dev publication | P1 | 📋 Planned |

### 14.2 Medium-term (v0.5.0 - v1.0.0)

| Feature | Priority | Description |
|---------|----------|-------------|
| Permission rationale UI | P2 | Built-in rationale dialog |
| Batch permission requests | P2 | Request multiple intentions |
| Permission change listener | P2 | Stream-based status updates |
| Localized permission names | P2 | User-friendly permission labels |
| Android 14+ photo picker | P2 | Alternative to storage permissions |

### 14.3 Long-term (v1.0.0+)

| Feature | Priority | Description |
|---------|----------|-------------|
| Web support | P3 | Browser Permissions API |
| macOS support | P3 | App Sandbox entitlements |
| Windows support | P3 | Capability-based permissions |
| Linux support | P3 | Flatpak portals |
| Custom intention builder | P3 | User-defined permission groups |

### 14.4 Potential New Intentions

| Intention | Use Case | Permissions |
|-----------|----------|-------------|
| `location` | Maps, geofencing | ACCESS_FINE/COARSE_LOCATION |
| `camera` | Photo/video capture | CAMERA |
| `microphone` | Audio recording | RECORD_AUDIO |
| `calendar` | Event management | READ/WRITE_CALENDAR |
| `bluetooth` | BLE devices | BLUETOOTH_* |
| `notifications` | Push notifications | POST_NOTIFICATIONS |
| `health` | Fitness data | ACTIVITY_RECOGNITION |

---

## 15. Risk Assessment

### 15.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Android permission changes | High | Medium | Monitor Android releases, maintain compatibility matrix |
| iOS API deprecations | Medium | Medium | Follow Apple developer documentation |
| Method channel instability | Low | High | Use stable Flutter APIs, extensive testing |
| Role API edge cases | Medium | Low | Graceful fallback to permission-only flow |

### 15.2 Project Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Scope creep | Medium | Medium | Strict intention-based scope |
| Platform implementation delays | Medium | High | Prioritize Android first, parallel iOS work |
| Community adoption | Unknown | Medium | Clear documentation, example apps |
| Competing packages | Medium | Low | Focus on intent-based differentiation |

### 15.3 Compliance Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Play Store policy changes | Medium | High | Monitor policy updates, adapt quickly |
| App Store policy changes | Medium | High | Monitor policy updates, adapt quickly |
| Privacy regulation (GDPR, etc.) | Low | Medium | No data collection, on-device only |

### 15.4 Known Issues

| Issue | Status | Workaround |
|-------|--------|------------|
| `Intention.device` uses inconsistent permission format | Open | Use `android.permission.READ_DEVICE_CONFIG` |
| Platform support not yet generated | Open | Run `flutter create -t plugin --platforms android,ios .` |
| pubspec.yaml has placeholder platform | Open | Replace `some_platform` after generation |

---

## 16. Appendices

### Appendix A: Android Permission Reference

#### A.1 SMS Permissions (Intention.texting)

| Permission | Protection Level | Description |
|------------|-----------------|-------------|
| `SEND_SMS` | Dangerous | Send SMS messages |
| `READ_SMS` | Dangerous | Read SMS messages |
| `RECEIVE_SMS` | Dangerous | Receive SMS messages |
| `WRITE_SMS` | Dangerous | Write SMS messages (deprecated) |
| `RECEIVE_WAP_PUSH` | Dangerous | Receive WAP push messages |
| `RECEIVE_MMS` | Dangerous | Receive MMS messages |

#### A.2 Phone Permissions (Intention.calling)

| Permission | Protection Level | Description |
|------------|-----------------|-------------|
| `READ_PHONE_STATE` | Dangerous | Read phone state and identity |
| `READ_PHONE_NUMBERS` | Dangerous | Read phone numbers (API 26+) |

#### A.3 Contact Permissions (Intention.contacts)

| Permission | Protection Level | Description |
|------------|-----------------|-------------|
| `READ_CONTACTS` | Dangerous | Read contacts |
| `WRITE_CONTACTS` | Dangerous | Write contacts |
| `MANAGE_OWN_CALLS` | Signature/AppOp | Manage calls via CallRedirectionService |

#### A.4 Storage Permissions (Intention.fileAccess)

| Permission | Protection Level | API Level | Description |
|------------|-----------------|-----------|-------------|
| `READ_EXTERNAL_STORAGE` | Dangerous | <33 | Read external storage |
| `READ_MEDIA_IMAGES` | Dangerous | 33+ | Read image files |
| `READ_MEDIA_VIDEO` | Dangerous | 33+ | Read video files |
| `READ_MEDIA_AUDIO` | Dangerous | 33+ | Read audio files |

### Appendix B: Android Role Reference

| Role | Constant | Default Handler For |
|------|----------|---------------------|
| SMS | `android.app.role.SMS` | SMS/MMS messaging |
| Dialer | `android.app.role.DIALER` | Phone calls |
| Browser | `android.app.role.BROWSER` | Web browsing |
| Home | `android.app.role.HOME` | Home screen launcher |
| Emergency | `android.app.role.EMERGENCY` | Emergency information |
| Assistant | `android.app.role.ASSISTANT` | Voice assistant |

### Appendix C: iOS Permission Reference

| Framework | Permission | Info.plist Key |
|-----------|------------|----------------|
| Contacts | CNContactStore | `NSContactsUsageDescription` |
| Photos | PHPhotoLibrary | `NSPhotoLibraryUsageDescription` |
| Camera | AVCaptureDevice | `NSCameraUsageDescription` |
| Microphone | AVAudioSession | `NSMicrophoneUsageDescription` |
| Location | CLLocationManager | `NSLocationWhenInUseUsageDescription` |

### Appendix D: Code Style Guide

```dart
// ✅ Use trailing commas for better diffs
final result = await permissions.request(
  Intention.texting,
);

// ✅ Use named parameters for clarity
Future<PermissionResult> request({
  required Intention intention,
  bool showRationale = true,
});

// ✅ Document all public APIs
/// Requests permissions for the given [intention].
///
/// Returns a [PermissionResult] containing the status of each
/// permission and whether the role was granted (if applicable).
///
/// Throws [PlatformException] if the platform call fails.
Future<PermissionResult> request(Intention intention);

// ✅ Use `switch` exhaustiveness for enums
String? get role {
  switch (this) {
    case Intention.texting:
      return 'android.app.role.SMS';
    case Intention.calling:
      return 'android.app.role.DIALER';
    case Intention.contacts:
    case Intention.device:
    case Intention.fileAccess:
      return null;
  }
  // No default - compiler enforces exhaustiveness
}
```

### Appendix E: Glossary

| Term | Definition |
|------|------------|
| **Dangerous Permission** | Android permission requiring runtime request |
| **Federated Plugin** | Flutter plugin architecture separating platform implementations |
| **Intention** | High-level user goal mapped to permission requirements |
| **Method Channel** | Flutter mechanism for Dart↔Native communication |
| **Platform Interface** | Abstract contract for platform implementations |
| **Role** | Android 10+ concept for default app designation |
| **Runtime Permission** | Permission requested during app execution (Android 6+) |

### Appendix F: Related Resources

- [Flutter Plugin Development](https://docs.flutter.dev/packages-and-plugins/developing-packages)
- [Android Permissions Overview](https://developer.android.com/guide/topics/permissions/overview)
- [Android RoleManager API](https://developer.android.com/reference/android/app/role/RoleManager)
- [iOS Privacy](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)
- [plugin_platform_interface Package](https://pub.dev/packages/plugin_platform_interface)

---

**Document Version**: 1.0
**Last Updated**: December 2025
**Authors**: Development Team
**Status**: Living Document - Updated with each major release
