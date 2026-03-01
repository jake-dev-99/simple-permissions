// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions_android/simple_permissions_android.dart';
import 'package:simple_permissions_android/src/android_permission_registry.dart';
import 'package:simple_permissions_android/src/handlers/permission_handler.dart';
import 'package:simple_permissions_android/src/permissions_api.dart';
import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

// =============================================================================
// Mock Pigeon HostApi
// =============================================================================

/// A fake [PermissionsApi] that records calls and returns configurable
/// results without needing a real platform channel.
class MockPermissionsApi implements PermissionsApi {
  // ---- Configurable responses ----

  /// Map of permission string → granted? for checkPermissions.
  Map<String, bool> checkResult = {};

  /// Map of permission string → granted? for requestPermissions.
  Map<String, bool> requestResult = {};

  /// Map of permission string → shouldShow? for rationale.
  Map<String, bool> rationaleResult = {};

  /// Role ID → held?
  Map<String, bool> roleHeld = {};

  /// Role ID → request result.
  Map<String, bool> roleRequestResult = {};

  /// Whether battery optimization exemption is active.
  bool batteryOptIgnoring = false;

  /// Result of requestIgnoreBatteryOptimizations.
  bool batteryOptRequestResult = false;

  /// Result of openAppSettings.
  bool openSettingsResult = true;

  /// Result of canScheduleExactAlarms.
  bool canScheduleExactAlarmsResult = true;

  /// Result of requestScheduleExactAlarms.
  bool requestScheduleExactAlarmsResult = true;

  /// Result of canRequestInstallPackages.
  bool canRequestInstallPackagesResult = true;

  /// Result of requestInstallPackages.
  bool requestInstallPackagesResult = true;

  /// Result of canDrawOverlays.
  bool canDrawOverlaysResult = true;

  /// Result of requestDrawOverlays.
  bool requestDrawOverlaysResult = true;

  /// Result of canManageExternalStorage.
  bool canManageExternalStorageResult = true;

  /// Result of requestManageExternalStorage.
  bool requestManageExternalStorageResult = true;

  /// SDK version to return from getSdkVersion.
  int sdkVersion = 34;

  // ---- Call tracking ----
  final List<String> calls = [];

  void reset() {
    checkResult = {};
    requestResult = {};
    rationaleResult = {};
    roleHeld = {};
    roleRequestResult = {};
    batteryOptIgnoring = false;
    batteryOptRequestResult = false;
    openSettingsResult = true;
    canScheduleExactAlarmsResult = true;
    requestScheduleExactAlarmsResult = true;
    canRequestInstallPackagesResult = true;
    requestInstallPackagesResult = true;
    canDrawOverlaysResult = true;
    requestDrawOverlaysResult = true;
    canManageExternalStorageResult = true;
    requestManageExternalStorageResult = true;
    sdkVersion = 34;
    calls.clear();
  }

  @override
  Future<Map<String, bool>> checkPermissions(List<String> permissions) async {
    calls.add('checkPermissions:${permissions.join(",")}');
    return {
      for (final p in permissions) p: checkResult[p] ?? false,
    };
  }

  @override
  Future<Map<String, bool>> requestPermissions(List<String> permissions) async {
    calls.add('requestPermissions:${permissions.join(",")}');
    return {
      for (final p in permissions) p: requestResult[p] ?? false,
    };
  }

  @override
  Future<bool> isRoleHeld(String roleId) async {
    calls.add('isRoleHeld:$roleId');
    return roleHeld[roleId] ?? false;
  }

  @override
  Future<bool> requestRole(String roleId) async {
    calls.add('requestRole:$roleId');
    return roleRequestResult[roleId] ?? false;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    calls.add('isIgnoringBatteryOptimizations');
    return batteryOptIgnoring;
  }

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async {
    calls.add('requestIgnoreBatteryOptimizations');
    return batteryOptRequestResult;
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    calls.add('canScheduleExactAlarms');
    return canScheduleExactAlarmsResult;
  }

  @override
  Future<bool> requestScheduleExactAlarms() async {
    calls.add('requestScheduleExactAlarms');
    return requestScheduleExactAlarmsResult;
  }

  @override
  Future<bool> canRequestInstallPackages() async {
    calls.add('canRequestInstallPackages');
    return canRequestInstallPackagesResult;
  }

  @override
  Future<bool> requestInstallPackages() async {
    calls.add('requestInstallPackages');
    return requestInstallPackagesResult;
  }

  @override
  Future<bool> canDrawOverlays() async {
    calls.add('canDrawOverlays');
    return canDrawOverlaysResult;
  }

  @override
  Future<bool> requestDrawOverlays() async {
    calls.add('requestDrawOverlays');
    return requestDrawOverlaysResult;
  }

  @override
  Future<bool> canManageExternalStorage() async {
    calls.add('canManageExternalStorage');
    return canManageExternalStorageResult;
  }

  @override
  Future<bool> requestManageExternalStorage() async {
    calls.add('requestManageExternalStorage');
    return requestManageExternalStorageResult;
  }

  @override
  Future<Map<String, bool>> shouldShowRequestPermissionRationale(
      List<String> permissions) async {
    calls.add('shouldShowRationale:${permissions.join(",")}');
    return {
      for (final p in permissions) p: rationaleResult[p] ?? false,
    };
  }

  @override
  Future<bool> openAppSettings() async {
    calls.add('openAppSettings');
    return openSettingsResult;
  }

  @override
  Future<int> getSdkVersion() async {
    calls.add('getSdkVersion');
    return sdkVersion;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // Basics
  // ===========================================================================

  group('SimplePermissionsAndroid', () {
    test('extends SimplePermissionsPlatform', () {
      final plugin = SimplePermissionsAndroid();
      expect(plugin, isA<SimplePermissionsPlatform>());
    });

    test('registerWith sets platform instance', () {
      SimplePermissionsAndroid.registerWith();
      expect(
        SimplePermissionsPlatform.instance,
        isA<SimplePermissionsAndroid>(),
      );
    });
  });

  // ===========================================================================
  // Registry coverage
  // ===========================================================================

  group('Registry coverage', () {
    late Map<Type, PermissionHandler> registry;

    setUp(() {
      registry = buildAndroidPermissionRegistry();
    });

    test('every Android-applicable Permission type has a handler', () {
      // All types that should be registered
      final expectedTypes = <Type>[
        // Camera
        CameraAccess,
        // Location
        CoarseLocation, FineLocation, BackgroundLocation,
        // Contacts
        ReadContacts, WriteContacts,
        // Storage
        ReadExternalStorage, ReadMediaImages, ReadMediaVideo, ReadMediaAudio,
        ReadMediaVisualUserSelected,
        // Phone
        ReadPhoneState, ReadPhoneNumbers, MakeCalls, AnswerCalls,
        ManageOwnCalls, ReadCallLog, WriteCallLog,
        ReadVoicemail, AddVoicemail, AcceptHandover,
        // Messaging
        SendSms, ReadSms, ReceiveSms, ReceiveMms, ReceiveWapPush,
        // Bluetooth
        BluetoothConnect, BluetoothScan, BluetoothAdvertise,
        BluetoothLegacy, BluetoothAdminLegacy,
        // Calendar
        ReadCalendar, WriteCalendar, ReadReminders, WriteReminders,
        // Notification
        PostNotifications,
        // Microphone
        RecordAudio,
        // Sensors
        BodySensors, BodySensorsBackground, ActivityRecognition, UwbRanging,
        // System
        BatteryOptimizationExemption, ScheduleExactAlarm,
        RequestInstallPackages, SystemAlertWindow, ManageExternalStorage,
        // Roles
        DefaultSmsApp, DefaultDialerApp, DefaultBrowserApp,
        DefaultAssistantApp,
        // Wifi
        NearbyWifiDevices,
      ];

      for (final type in expectedTypes) {
        expect(
          registry.containsKey(type),
          isTrue,
          reason: '$type is not registered',
        );
      }
    });

    test('iOS-only permissions are NOT registered', () {
      expect(registry.containsKey(AppTrackingTransparency), isFalse);
      expect(registry.containsKey(ReadHealth), isFalse);
      expect(registry.containsKey(WriteHealth), isFalse);
    });
  });

  // ===========================================================================
  // RuntimePermissionHandler
  // ===========================================================================

  group('RuntimePermissionHandler', () {
    late MockPermissionsApi mockApi;

    setUp(() {
      mockApi = MockPermissionsApi();
    });

    test('check returns granted when permission is granted', () async {
      const handler = RuntimePermissionHandler('android.permission.CAMERA');
      mockApi.checkResult = {'android.permission.CAMERA': true};
      final result = await handler.check(mockApi);
      expect(result, PermissionGrant.granted);
    });

    test('check returns denied when permission is not granted', () async {
      const handler = RuntimePermissionHandler('android.permission.CAMERA');
      mockApi.checkResult = {'android.permission.CAMERA': false};
      final result = await handler.check(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('request returns granted when already granted', () async {
      const handler = RuntimePermissionHandler('android.permission.CAMERA');
      mockApi.checkResult = {'android.permission.CAMERA': true};
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      // Should not have called requestPermissions
      expect(
        mockApi.calls.where((c) => c.startsWith('requestPermissions')),
        isEmpty,
      );
    });

    test('request returns granted after successful request', () async {
      const handler = RuntimePermissionHandler('android.permission.CAMERA');
      mockApi.checkResult = {'android.permission.CAMERA': false};
      mockApi.requestResult = {'android.permission.CAMERA': true};
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
    });

    test('request returns denied when rationale is true (can ask again)',
        () async {
      const handler = RuntimePermissionHandler('android.permission.CAMERA');
      mockApi.checkResult = {'android.permission.CAMERA': false};
      mockApi.requestResult = {'android.permission.CAMERA': false};
      mockApi.rationaleResult = {'android.permission.CAMERA': true};
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test(
        'request returns permanentlyDenied when rationale is false after denial',
        () async {
      const handler = RuntimePermissionHandler('android.permission.CAMERA');
      mockApi.checkResult = {'android.permission.CAMERA': false};
      mockApi.requestResult = {'android.permission.CAMERA': false};
      mockApi.rationaleResult = {'android.permission.CAMERA': false};
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.permanentlyDenied);
    });

    test('background location request checks foreground grants first',
        () async {
      const handler = RuntimePermissionHandler(
        'android.permission.ACCESS_BACKGROUND_LOCATION',
      );
      mockApi.checkResult = {
        'android.permission.ACCESS_BACKGROUND_LOCATION': false,
        'android.permission.ACCESS_FINE_LOCATION': false,
        'android.permission.ACCESS_COARSE_LOCATION': false,
      };
      mockApi.requestResult = {
        'android.permission.ACCESS_BACKGROUND_LOCATION': false
      };
      mockApi.rationaleResult = {
        'android.permission.ACCESS_BACKGROUND_LOCATION': true
      };

      final result = await handler.request(mockApi);

      expect(result, PermissionGrant.denied);
      expect(
        mockApi.calls,
        contains(
          'checkPermissions:android.permission.ACCESS_FINE_LOCATION,android.permission.ACCESS_COARSE_LOCATION',
        ),
      );
    });

    test('isSupported respects minSdk', () {
      const handler = RuntimePermissionHandler(
        'android.permission.POST_NOTIFICATIONS',
        minSdk: 33,
      );
      expect(handler.isSupported(() => 32), isFalse);
      expect(handler.isSupported(() => 33), isTrue);
      expect(handler.isSupported(() => 34), isTrue);
    });

    test('isSupported respects maxSdk', () {
      const handler = RuntimePermissionHandler(
        'android.permission.READ_EXTERNAL_STORAGE',
        maxSdk: 32,
      );
      expect(handler.isSupported(() => 31), isTrue);
      expect(handler.isSupported(() => 32), isTrue);
      expect(handler.isSupported(() => 33), isFalse);
    });

    test('isSupported with both bounds', () {
      const handler = RuntimePermissionHandler(
        'test.perm',
        minSdk: 30,
        maxSdk: 32,
      );
      expect(handler.isSupported(() => 29), isFalse);
      expect(handler.isSupported(() => 30), isTrue);
      expect(handler.isSupported(() => 32), isTrue);
      expect(handler.isSupported(() => 33), isFalse);
    });

    test('isSupported with no bounds returns true', () {
      const handler = RuntimePermissionHandler('test.perm');
      expect(handler.isSupported(() => 1), isTrue);
      expect(handler.isSupported(() => 99), isTrue);
    });
  });

  // ===========================================================================
  // RoleHandler
  // ===========================================================================

  group('RoleHandler', () {
    late MockPermissionsApi mockApi;

    setUp(() {
      mockApi = MockPermissionsApi();
    });

    test('check returns granted when role is held', () async {
      const handler = RoleHandler('android.app.role.SMS');
      mockApi.roleHeld = {'android.app.role.SMS': true};
      final result = await handler.check(mockApi);
      expect(result, PermissionGrant.granted);
    });

    test('check returns denied when role is not held', () async {
      const handler = RoleHandler('android.app.role.SMS');
      mockApi.roleHeld = {'android.app.role.SMS': false};
      final result = await handler.check(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('request returns granted when already held', () async {
      const handler = RoleHandler('android.app.role.SMS');
      mockApi.roleHeld = {'android.app.role.SMS': true};
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls.where((c) => c.startsWith('requestRole')),
        isEmpty,
      );
    });

    test('request sends requestRole and returns result', () async {
      const handler = RoleHandler('android.app.role.SMS');
      mockApi.roleHeld = {'android.app.role.SMS': false};
      mockApi.roleRequestResult = {'android.app.role.SMS': true};
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls,
        contains('requestRole:android.app.role.SMS'),
      );
    });

    test('isSupported always returns true', () {
      const handler = RoleHandler('android.app.role.SMS');
      expect(handler.isSupported(() => 30), isTrue);
      expect(handler.isSupported(() => 35), isTrue);
    });
  });

  // ===========================================================================
  // SystemSettingHandler
  // ===========================================================================

  group('SystemSettingHandler', () {
    late MockPermissionsApi mockApi;

    setUp(() {
      mockApi = MockPermissionsApi();
    });

    test('check returns granted when battery opt is ignored', () async {
      const handler =
          SystemSettingHandler(SystemSettingType.batteryOptimization);
      mockApi.batteryOptIgnoring = true;
      final result = await handler.check(mockApi);
      expect(result, PermissionGrant.granted);
    });

    test('check returns denied when battery opt is not ignored', () async {
      const handler =
          SystemSettingHandler(SystemSettingType.batteryOptimization);
      mockApi.batteryOptIgnoring = false;
      final result = await handler.check(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('request returns granted when already ignoring', () async {
      const handler =
          SystemSettingHandler(SystemSettingType.batteryOptimization);
      mockApi.batteryOptIgnoring = true;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
    });

    test('request delegates to requestIgnoreBatteryOptimizations', () async {
      const handler =
          SystemSettingHandler(SystemSettingType.batteryOptimization);
      mockApi.batteryOptIgnoring = false;
      mockApi.batteryOptRequestResult = true;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls,
        contains('requestIgnoreBatteryOptimizations'),
      );
    });

    test('schedule exact alarm request uses requestScheduleExactAlarms',
        () async {
      const handler =
          SystemSettingHandler(SystemSettingType.scheduleExactAlarm);
      mockApi.canScheduleExactAlarmsResult = false;
      mockApi.requestScheduleExactAlarmsResult = true;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls,
        contains('requestScheduleExactAlarms'),
      );
    });

    test('schedule exact alarm check returns denied when unavailable',
        () async {
      const handler =
          SystemSettingHandler(SystemSettingType.scheduleExactAlarm);
      mockApi.canScheduleExactAlarmsResult = false;
      final result = await handler.check(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('schedule exact alarm request returns denied when request fails',
        () async {
      const handler =
          SystemSettingHandler(SystemSettingType.scheduleExactAlarm);
      mockApi.canScheduleExactAlarmsResult = false;
      mockApi.requestScheduleExactAlarmsResult = false;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('schedule exact alarm request short-circuits when already granted',
        () async {
      const handler =
          SystemSettingHandler(SystemSettingType.scheduleExactAlarm);
      mockApi.canScheduleExactAlarmsResult = true;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, isNot(contains('requestScheduleExactAlarms')));
    });

    test('install packages request uses requestInstallPackages', () async {
      const handler =
          SystemSettingHandler(SystemSettingType.requestInstallPackages);
      mockApi.canRequestInstallPackagesResult = false;
      mockApi.requestInstallPackagesResult = true;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls,
        contains('requestInstallPackages'),
      );
    });

    test('install packages check returns denied when unavailable', () async {
      const handler =
          SystemSettingHandler(SystemSettingType.requestInstallPackages);
      mockApi.canRequestInstallPackagesResult = false;
      final result = await handler.check(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('install packages request returns denied when request fails',
        () async {
      const handler =
          SystemSettingHandler(SystemSettingType.requestInstallPackages);
      mockApi.canRequestInstallPackagesResult = false;
      mockApi.requestInstallPackagesResult = false;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('install packages request short-circuits when already granted',
        () async {
      const handler =
          SystemSettingHandler(SystemSettingType.requestInstallPackages);
      mockApi.canRequestInstallPackagesResult = true;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, isNot(contains('requestInstallPackages')));
    });

    test('overlay request uses requestDrawOverlays', () async {
      const handler = SystemSettingHandler(SystemSettingType.systemAlertWindow);
      mockApi.canDrawOverlaysResult = false;
      mockApi.requestDrawOverlaysResult = true;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls,
        contains('requestDrawOverlays'),
      );
    });

    test('overlay check returns denied when unavailable', () async {
      const handler = SystemSettingHandler(SystemSettingType.systemAlertWindow);
      mockApi.canDrawOverlaysResult = false;
      final result = await handler.check(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('overlay request returns denied when request fails', () async {
      const handler = SystemSettingHandler(SystemSettingType.systemAlertWindow);
      mockApi.canDrawOverlaysResult = false;
      mockApi.requestDrawOverlaysResult = false;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('overlay request short-circuits when already granted', () async {
      const handler = SystemSettingHandler(SystemSettingType.systemAlertWindow);
      mockApi.canDrawOverlaysResult = true;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, isNot(contains('requestDrawOverlays')));
    });

    test('manage external storage request uses requestManageExternalStorage',
        () async {
      const handler =
          SystemSettingHandler(SystemSettingType.manageExternalStorage);
      mockApi.canManageExternalStorageResult = false;
      mockApi.requestManageExternalStorageResult = true;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls,
        contains('requestManageExternalStorage'),
      );
    });

    test('manage external storage check returns denied when unavailable',
        () async {
      const handler =
          SystemSettingHandler(SystemSettingType.manageExternalStorage);
      mockApi.canManageExternalStorageResult = false;
      final result = await handler.check(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('manage external storage request returns denied when request fails',
        () async {
      const handler =
          SystemSettingHandler(SystemSettingType.manageExternalStorage);
      mockApi.canManageExternalStorageResult = false;
      mockApi.requestManageExternalStorageResult = false;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.denied);
    });

    test('manage external storage request short-circuits when already granted',
        () async {
      const handler =
          SystemSettingHandler(SystemSettingType.manageExternalStorage);
      mockApi.canManageExternalStorageResult = true;
      final result = await handler.request(mockApi);
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, isNot(contains('requestManageExternalStorage')));
    });

    test('isSupported uses per-setting SDK minimums', () {
      const battery =
          SystemSettingHandler(SystemSettingType.batteryOptimization);
      const exact = SystemSettingHandler(SystemSettingType.scheduleExactAlarm);
      const install =
          SystemSettingHandler(SystemSettingType.requestInstallPackages);
      const overlay = SystemSettingHandler(SystemSettingType.systemAlertWindow);
      const manage =
          SystemSettingHandler(SystemSettingType.manageExternalStorage);

      expect(battery.isSupported(() => 22), isFalse);
      expect(battery.isSupported(() => 23), isTrue);
      expect(exact.isSupported(() => 30), isFalse);
      expect(exact.isSupported(() => 31), isTrue);
      expect(install.isSupported(() => 25), isFalse);
      expect(install.isSupported(() => 26), isTrue);
      expect(overlay.isSupported(() => 22), isFalse);
      expect(overlay.isSupported(() => 23), isTrue);
      expect(manage.isSupported(() => 29), isFalse);
      expect(manage.isSupported(() => 30), isTrue);
    });
  });

  // ===========================================================================
  // Integration: SimplePermissionsAndroid v2 API
  // ===========================================================================

  group('v2 API integration', () {
    late MockPermissionsApi mockApi;
    late SimplePermissionsAndroid plugin;

    setUp(() {
      mockApi = MockPermissionsApi();
      plugin = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 34,
      );
    });

    test('check routes ReadContacts to correct Android permission', () async {
      mockApi.checkResult = {'android.permission.READ_CONTACTS': true};
      final result = await plugin.check(const ReadContacts());
      expect(result, PermissionGrant.granted);
    });

    test('check returns notApplicable for iOS-only permission', () async {
      final result = await plugin.check(const AppTrackingTransparency());
      expect(result, PermissionGrant.notApplicable);
    });

    test('check returns notAvailable for unsupported SDK version', () async {
      final plugin31 = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 31,
      );
      final result = await plugin31.check(const ReadMediaImages());
      expect(result, PermissionGrant.notAvailable);
    });

    test('request routes through handler and returns grant', () async {
      mockApi.checkResult = {'android.permission.READ_CONTACTS': false};
      mockApi.requestResult = {'android.permission.READ_CONTACTS': true};
      final result = await plugin.request(const ReadContacts());
      expect(result, PermissionGrant.granted);
    });

    test(
        'request BackgroundLocation on API 30+ returns denied when foreground missing',
        () async {
      mockApi.checkResult = {
        'android.permission.ACCESS_BACKGROUND_LOCATION': false,
        'android.permission.ACCESS_FINE_LOCATION': false,
        'android.permission.ACCESS_COARSE_LOCATION': false,
      };

      final result = await plugin.request(const BackgroundLocation());

      expect(result, PermissionGrant.denied);
      expect(
        mockApi.calls.where(
          (c) =>
              c ==
              'requestPermissions:android.permission.ACCESS_BACKGROUND_LOCATION',
        ),
        isEmpty,
      );
    });

    test(
        'request BackgroundLocation on API 30+ proceeds when foreground granted',
        () async {
      mockApi.checkResult = {
        'android.permission.ACCESS_BACKGROUND_LOCATION': false,
        'android.permission.ACCESS_FINE_LOCATION': true,
      };
      mockApi.requestResult = {
        'android.permission.ACCESS_BACKGROUND_LOCATION': true,
      };

      final result = await plugin.request(const BackgroundLocation());

      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls,
        contains(
            'requestPermissions:android.permission.ACCESS_BACKGROUND_LOCATION'),
      );
    });

    test('request correctly classifies permanent denial', () async {
      mockApi.checkResult = {'android.permission.CAMERA': false};
      mockApi.requestResult = {'android.permission.CAMERA': false};
      mockApi.rationaleResult = {'android.permission.CAMERA': false};
      final result = await plugin.request(const CameraAccess());
      expect(result, PermissionGrant.permanentlyDenied);
    });

    test('request correctly classifies temporary denial', () async {
      mockApi.checkResult = {'android.permission.CAMERA': false};
      mockApi.requestResult = {'android.permission.CAMERA': false};
      mockApi.rationaleResult = {'android.permission.CAMERA': true};
      final result = await plugin.request(const CameraAccess());
      expect(result, PermissionGrant.denied);
    });

    test('isSupported returns true for supported permission', () {
      expect(plugin.isSupported(const ReadContacts()), isTrue);
    });

    test('isSupported returns false for iOS-only permission', () {
      expect(plugin.isSupported(const AppTrackingTransparency()), isFalse);
    });

    test('isSupported returns false for wrong SDK version', () {
      final plugin31 = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 31,
      );
      expect(plugin31.isSupported(const ReadMediaImages()), isFalse);
      expect(plugin31.isSupported(const ReadExternalStorage()), isTrue);
    });

    test('isSupported for system settings respects SDK minimums', () {
      final plugin22 = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 22,
      );
      final plugin30 = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 30,
      );
      expect(
          plugin22.isSupported(const BatteryOptimizationExemption()), isFalse);
      expect(plugin30.isSupported(const ScheduleExactAlarm()), isFalse);
      expect(plugin30.isSupported(const RequestInstallPackages()), isTrue);
      expect(plugin30.isSupported(const ManageExternalStorage()), isTrue);
    });

    test('isSupported respects SDK minimums for niche Android permissions', () {
      final plugin30 = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 30,
      );
      final plugin31 = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 31,
      );
      final plugin32 = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 32,
      );
      final plugin33 = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 33,
      );

      expect(plugin30.isSupported(const UwbRanging()), isFalse);
      expect(plugin31.isSupported(const UwbRanging()), isTrue);
      expect(plugin32.isSupported(const BodySensorsBackground()), isFalse);
      expect(plugin33.isSupported(const BodySensorsBackground()), isTrue);
    });

    test('openAppSettings delegates to host API', () async {
      mockApi.openSettingsResult = true;
      final result = await plugin.openAppSettings();
      expect(result, isTrue);
      expect(mockApi.calls, contains('openAppSettings'));
    });

    test('checkAll returns aggregate PermissionResult', () async {
      mockApi.checkResult = {
        'android.permission.READ_CONTACTS': true,
        'android.permission.WRITE_CONTACTS': false,
      };
      final result = await plugin.checkAll([
        const ReadContacts(),
        const WriteContacts(),
      ]);
      expect(result.isFullyGranted, isFalse);
      expect(result[const ReadContacts()], PermissionGrant.granted);
      expect(result[const WriteContacts()], PermissionGrant.denied);
      expect(
        mockApi.calls.where((c) => c.startsWith('checkPermissions')).length,
        1,
      );
    });

    test('requestAll returns aggregate PermissionResult', () async {
      mockApi.checkResult = {
        'android.permission.READ_CONTACTS': false,
        'android.permission.WRITE_CONTACTS': false,
      };
      mockApi.requestResult = {
        'android.permission.READ_CONTACTS': true,
        'android.permission.WRITE_CONTACTS': true,
      };
      final result = await plugin.requestAll([
        const ReadContacts(),
        const WriteContacts(),
      ]);
      expect(result.isFullyGranted, isTrue);
      expect(
        mockApi.calls.where((c) => c.startsWith('checkPermissions')).length,
        1,
      );
      expect(
        mockApi.calls.where((c) => c.startsWith('requestPermissions')).length,
        1,
      );
      expect(
        mockApi.calls.where((c) => c.startsWith('shouldShowRationale')),
        isEmpty,
      );
    });

    test('requestAll classifies denied runtime permissions in batch', () async {
      mockApi.checkResult = {
        'android.permission.READ_CONTACTS': false,
        'android.permission.WRITE_CONTACTS': false,
      };
      mockApi.requestResult = {
        'android.permission.READ_CONTACTS': false,
        'android.permission.WRITE_CONTACTS': false,
      };
      mockApi.rationaleResult = {
        'android.permission.READ_CONTACTS': true,
        'android.permission.WRITE_CONTACTS': false,
      };
      final result = await plugin.requestAll([
        const ReadContacts(),
        const WriteContacts(),
      ]);
      expect(result[const ReadContacts()], PermissionGrant.denied);
      expect(
        result[const WriteContacts()],
        PermissionGrant.permanentlyDenied,
      );
      expect(
        mockApi.calls.where((c) => c.startsWith('shouldShowRationale')).length,
        1,
      );
    });

    test(
        'requestAll excludes BackgroundLocation request on API 30+ when foreground missing',
        () async {
      mockApi.checkResult = {
        'android.permission.ACCESS_BACKGROUND_LOCATION': false,
        'android.permission.CAMERA': false,
        'android.permission.ACCESS_FINE_LOCATION': false,
        'android.permission.ACCESS_COARSE_LOCATION': false,
      };
      mockApi.requestResult = {'android.permission.CAMERA': true};

      final result = await plugin.requestAll([
        const BackgroundLocation(),
        const CameraAccess(),
      ]);

      expect(result[const BackgroundLocation()], PermissionGrant.denied);
      expect(result[const CameraAccess()], PermissionGrant.granted);
      expect(
        mockApi.calls,
        contains('requestPermissions:android.permission.CAMERA'),
      );
      expect(
        mockApi.calls.where(
          (c) => c.contains('android.permission.ACCESS_BACKGROUND_LOCATION'),
        ),
        isNot(contains(
            'requestPermissions:android.permission.ACCESS_BACKGROUND_LOCATION')),
      );
    });

    test('check ScheduleExactAlarm routes through system setting handler',
        () async {
      mockApi.canScheduleExactAlarmsResult = false;
      final result = await plugin.check(const ScheduleExactAlarm());
      expect(result, PermissionGrant.denied);
      expect(mockApi.calls, contains('canScheduleExactAlarms'));
    });

    test('request ScheduleExactAlarm routes through system setting handler',
        () async {
      mockApi.canScheduleExactAlarmsResult = false;
      mockApi.requestScheduleExactAlarmsResult = true;
      final result = await plugin.request(const ScheduleExactAlarm());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, contains('requestScheduleExactAlarms'));
    });

    test('check RequestInstallPackages routes through system setting handler',
        () async {
      mockApi.canRequestInstallPackagesResult = false;
      final result = await plugin.check(const RequestInstallPackages());
      expect(result, PermissionGrant.denied);
      expect(mockApi.calls, contains('canRequestInstallPackages'));
    });

    test('request RequestInstallPackages routes through system setting handler',
        () async {
      mockApi.canRequestInstallPackagesResult = false;
      mockApi.requestInstallPackagesResult = true;
      final result = await plugin.request(const RequestInstallPackages());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, contains('requestInstallPackages'));
    });

    test('check SystemAlertWindow routes through system setting handler',
        () async {
      mockApi.canDrawOverlaysResult = false;
      final result = await plugin.check(const SystemAlertWindow());
      expect(result, PermissionGrant.denied);
      expect(mockApi.calls, contains('canDrawOverlays'));
    });

    test('request SystemAlertWindow routes through system setting handler',
        () async {
      mockApi.canDrawOverlaysResult = false;
      mockApi.requestDrawOverlaysResult = true;
      final result = await plugin.request(const SystemAlertWindow());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, contains('requestDrawOverlays'));
    });

    test('check ManageExternalStorage routes through system setting handler',
        () async {
      mockApi.canManageExternalStorageResult = false;
      final result = await plugin.check(const ManageExternalStorage());
      expect(result, PermissionGrant.denied);
      expect(mockApi.calls, contains('canManageExternalStorage'));
    });

    test('request ManageExternalStorage routes through system setting handler',
        () async {
      mockApi.canManageExternalStorageResult = false;
      mockApi.requestManageExternalStorageResult = true;
      final result = await plugin.request(const ManageExternalStorage());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, contains('requestManageExternalStorage'));
    });

    test('checkAll batches runtime and handles non-runtime sequentially',
        () async {
      mockApi.checkResult = {'android.permission.READ_CONTACTS': true};
      mockApi.roleHeld = {'android.app.role.SMS': false};
      final result = await plugin.checkAll([
        const ReadContacts(),
        const DefaultSmsApp(),
      ]);
      expect(result[const ReadContacts()], PermissionGrant.granted);
      expect(result[const DefaultSmsApp()], PermissionGrant.denied);
      expect(
        mockApi.calls.where((c) => c.startsWith('checkPermissions')).length,
        1,
      );
      expect(mockApi.calls, contains('isRoleHeld:android.app.role.SMS'));
    });

    test('checkLocationAccuracy returns precise when fine location granted',
        () async {
      mockApi.checkResult = {
        'android.permission.ACCESS_FINE_LOCATION': true,
        'android.permission.ACCESS_COARSE_LOCATION': true,
      };

      final result = await plugin.checkLocationAccuracy();
      expect(result, LocationAccuracyStatus.precise);
    });

    test('checkLocationAccuracy returns reduced when only coarse granted',
        () async {
      mockApi.checkResult = {
        'android.permission.ACCESS_FINE_LOCATION': false,
        'android.permission.ACCESS_COARSE_LOCATION': true,
      };

      final result = await plugin.checkLocationAccuracy();
      expect(result, LocationAccuracyStatus.reduced);
    });

    test('checkLocationAccuracy returns none when location not granted',
        () async {
      mockApi.checkResult = {
        'android.permission.ACCESS_FINE_LOCATION': false,
        'android.permission.ACCESS_COARSE_LOCATION': false,
      };

      final result = await plugin.checkLocationAccuracy();
      expect(result, LocationAccuracyStatus.none);
    });
  });

  // ===========================================================================
  // VersionedPermission resolution through plugin
  // ===========================================================================

  group('VersionedPermission resolution', () {
    late MockPermissionsApi mockApi;

    test('resolves images() to READ_MEDIA_IMAGES on API 34', () async {
      mockApi = MockPermissionsApi();
      mockApi.checkResult = {'android.permission.READ_MEDIA_IMAGES': true};
      final plugin = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 34,
      );
      final result = await plugin.check(const VersionedPermission.images());
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls.last,
        'checkPermissions:android.permission.READ_MEDIA_IMAGES',
      );
    });

    test('resolves images() to READ_EXTERNAL_STORAGE on API 32', () async {
      mockApi = MockPermissionsApi();
      mockApi.checkResult = {'android.permission.READ_EXTERNAL_STORAGE': true};
      final plugin = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 32,
      );
      final result = await plugin.check(const VersionedPermission.images());
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls.last,
        'checkPermissions:android.permission.READ_EXTERNAL_STORAGE',
      );
    });

    test('resolves bluetoothConnect() to BLUETOOTH_CONNECT on API 31',
        () async {
      mockApi = MockPermissionsApi();
      mockApi.checkResult = {'android.permission.BLUETOOTH_CONNECT': true};
      final plugin = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 31,
      );
      final result =
          await plugin.check(const VersionedPermission.bluetoothConnect());
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls.last,
        'checkPermissions:android.permission.BLUETOOTH_CONNECT',
      );
    });

    test('resolves bluetoothConnect() to BLUETOOTH on API 30', () async {
      mockApi = MockPermissionsApi();
      mockApi.checkResult = {'android.permission.BLUETOOTH': true};
      final plugin = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 30,
      );
      final result =
          await plugin.check(const VersionedPermission.bluetoothConnect());
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls.last,
        'checkPermissions:android.permission.BLUETOOTH',
      );
    });
  });

  group('SDK loading', () {
    test('fetches SDK before first versioned check and caches it', () async {
      final mockApi = MockPermissionsApi()
        ..sdkVersion = 32
        ..checkResult = {'android.permission.READ_EXTERNAL_STORAGE': true};
      final plugin = SimplePermissionsAndroid(api: mockApi);

      final first = await plugin.check(const VersionedPermission.images());
      expect(first, PermissionGrant.granted);
      expect(mockApi.calls.first, 'getSdkVersion');
      expect(
        mockApi.calls,
        contains('checkPermissions:android.permission.READ_EXTERNAL_STORAGE'),
      );

      mockApi.calls.clear();
      await plugin.check(const VersionedPermission.images());
      expect(
        mockApi.calls.where((call) => call == 'getSdkVersion').length,
        0,
      );
    });
  });

  // ===========================================================================
  // Role handling through plugin
  // ===========================================================================

  group('Role handling', () {
    late MockPermissionsApi mockApi;
    late SimplePermissionsAndroid plugin;

    setUp(() {
      mockApi = MockPermissionsApi();
      plugin = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 34,
      );
    });

    test('check DefaultSmsApp routes to isRoleHeld', () async {
      mockApi.roleHeld = {'android.app.role.SMS': true};
      final result = await plugin.check(const DefaultSmsApp());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, contains('isRoleHeld:android.app.role.SMS'));
    });

    test('request DefaultDialerApp routes to requestRole', () async {
      mockApi.roleHeld = {'android.app.role.DIALER': false};
      mockApi.roleRequestResult = {'android.app.role.DIALER': true};
      final result = await plugin.request(const DefaultDialerApp());
      expect(result, PermissionGrant.granted);
      expect(
        mockApi.calls,
        contains('requestRole:android.app.role.DIALER'),
      );
    });
  });

  // ===========================================================================
  // Battery optimization through plugin
  // ===========================================================================

  group('Battery optimization', () {
    late MockPermissionsApi mockApi;
    late SimplePermissionsAndroid plugin;

    setUp(() {
      mockApi = MockPermissionsApi();
      plugin = SimplePermissionsAndroid(
        api: mockApi,
        sdkVersionOverride: () => 34,
      );
    });

    test('check BatteryOptimizationExemption routes correctly', () async {
      mockApi.batteryOptIgnoring = true;
      final result = await plugin.check(const BatteryOptimizationExemption());
      expect(result, PermissionGrant.granted);
    });

    test('request BatteryOptimizationExemption routes correctly', () async {
      mockApi.batteryOptIgnoring = false;
      mockApi.batteryOptRequestResult = true;
      final result = await plugin.request(const BatteryOptimizationExemption());
      expect(result, PermissionGrant.granted);
    });
  });

  // ===========================================================================
  // Deprecated capability backward compatibility
  // ===========================================================================
}
