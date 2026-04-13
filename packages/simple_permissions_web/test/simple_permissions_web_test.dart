import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';
import 'package:simple_permissions_web/simple_permissions_web.dart';
import 'package:simple_permissions_web/src/web_permission_registry.dart';
import 'package:simple_permissions_web/src/web_permissions_api_base.dart';

/// Mock implementation of [WebPermissionsApi] for testing.
class MockWebPermissionsApi implements WebPermissionsApi {
  final List<String> calls = [];

  /// Map of permission name → state string ('granted', 'denied', 'prompt').
  Map<String, String?> queryResults = {};

  bool requestCameraResult = false;
  bool requestMicrophoneResult = false;
  bool requestGeolocationResult = false;
  String requestNotificationsResult = 'denied';

  @override
  Future<String?> queryPermission(String name) async {
    calls.add('query:$name');
    return queryResults[name];
  }

  @override
  Future<bool> requestCamera() async {
    calls.add('requestCamera');
    return requestCameraResult;
  }

  @override
  Future<bool> requestMicrophone() async {
    calls.add('requestMicrophone');
    return requestMicrophoneResult;
  }

  @override
  Future<bool> requestGeolocation() async {
    calls.add('requestGeolocation');
    return requestGeolocationResult;
  }

  @override
  Future<String> requestNotifications() async {
    calls.add('requestNotifications');
    return requestNotificationsResult;
  }

  @override
  Future<bool> openAppSettings() async {
    calls.add('openAppSettings');
    return false;
  }
}

void main() {
  late MockWebPermissionsApi mockApi;
  late SimplePermissionsWeb plugin;

  setUp(() {
    mockApi = MockWebPermissionsApi();
    plugin = SimplePermissionsWeb(api: mockApi);
  });

  group('SimplePermissionsWeb', () {
    test('extends SimplePermissionsPlatform', () {
      expect(plugin, isA<SimplePermissionsPlatform>());
    });

    test('can be set as platform instance', () {
      SimplePermissionsPlatform.instance =
          SimplePermissionsWeb(api: MockWebPermissionsApi());
      expect(
        SimplePermissionsPlatform.instance,
        isA<SimplePermissionsWeb>(),
      );
    });
  });

  group('check()', () {
    test('returns granted when browser reports granted', () async {
      mockApi.queryResults = {'camera': 'granted'};
      final result = await plugin.check(const CameraAccess());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, ['query:camera']);
    });

    test('returns permanentlyDenied when browser reports denied', () async {
      mockApi.queryResults = {'microphone': 'denied'};
      final result = await plugin.check(const RecordAudio());
      expect(result, PermissionGrant.permanentlyDenied);
    });

    test('returns denied when browser reports prompt', () async {
      mockApi.queryResults = {'geolocation': 'prompt'};
      final result = await plugin.check(const FineLocation());
      expect(result, PermissionGrant.denied);
    });

    test('returns notApplicable when query returns null', () async {
      mockApi.queryResults = {'camera': null};
      final result = await plugin.check(const CameraAccess());
      expect(result, PermissionGrant.notApplicable);
    });

    test('returns notApplicable for unregistered permissions', () async {
      final result = await plugin.check(const ReadContacts());
      expect(result, PermissionGrant.notApplicable);
      expect(mockApi.calls, isEmpty);
    });

    test('routes CoarseLocation to geolocation', () async {
      mockApi.queryResults = {'geolocation': 'granted'};
      final result = await plugin.check(const CoarseLocation());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, ['query:geolocation']);
    });

    test('routes PostNotifications to notifications', () async {
      mockApi.queryResults = {'notifications': 'prompt'};
      final result = await plugin.check(const PostNotifications());
      expect(result, PermissionGrant.denied);
    });
  });

  group('request()', () {
    test('returns granted without requesting when already granted', () async {
      mockApi.queryResults = {'camera': 'granted'};
      final result = await plugin.request(const CameraAccess());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, ['query:camera']);
    });

    test('returns permanentlyDenied without requesting when denied', () async {
      mockApi.queryResults = {'camera': 'denied'};
      final result = await plugin.request(const CameraAccess());
      expect(result, PermissionGrant.permanentlyDenied);
      expect(mockApi.calls, ['query:camera']);
    });

    test('requests camera when state is prompt', () async {
      mockApi.queryResults = {'camera': 'prompt'};
      mockApi.requestCameraResult = true;
      final result = await plugin.request(const CameraAccess());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, ['query:camera', 'requestCamera']);
    });

    test('returns denied when camera request fails', () async {
      mockApi.queryResults = {'camera': 'prompt'};
      mockApi.requestCameraResult = false;
      final result = await plugin.request(const CameraAccess());
      expect(result, PermissionGrant.denied);
    });

    test('requests microphone', () async {
      mockApi.queryResults = {'microphone': 'prompt'};
      mockApi.requestMicrophoneResult = true;
      final result = await plugin.request(const RecordAudio());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, ['query:microphone', 'requestMicrophone']);
    });

    test('requests geolocation for FineLocation', () async {
      mockApi.queryResults = {'geolocation': 'prompt'};
      mockApi.requestGeolocationResult = true;
      final result = await plugin.request(const FineLocation());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, ['query:geolocation', 'requestGeolocation']);
    });

    test('requests geolocation for CoarseLocation', () async {
      mockApi.queryResults = {'geolocation': 'prompt'};
      mockApi.requestGeolocationResult = false;
      final result = await plugin.request(const CoarseLocation());
      expect(result, PermissionGrant.denied);
      expect(mockApi.calls, ['query:geolocation', 'requestGeolocation']);
    });

    test('requests notifications', () async {
      mockApi.queryResults = {'notifications': 'prompt'};
      mockApi.requestNotificationsResult = 'granted';
      final result = await plugin.request(const PostNotifications());
      expect(result, PermissionGrant.granted);
      expect(mockApi.calls, ['query:notifications', 'requestNotifications']);
    });

    test('returns denied when notification request returns default', () async {
      mockApi.queryResults = {'notifications': 'prompt'};
      mockApi.requestNotificationsResult = 'default';
      final result = await plugin.request(const PostNotifications());
      expect(result, PermissionGrant.denied);
    });

    test('returns notApplicable for unregistered permissions', () async {
      final result = await plugin.request(const ReadContacts());
      expect(result, PermissionGrant.notApplicable);
      expect(mockApi.calls, isEmpty);
    });
  });

  group('isSupported()', () {
    test('returns true for registered permissions', () async {
      expect(await plugin.isSupported(const CameraAccess()), isTrue);
      expect(await plugin.isSupported(const RecordAudio()), isTrue);
      expect(await plugin.isSupported(const FineLocation()), isTrue);
      expect(await plugin.isSupported(const CoarseLocation()), isTrue);
      expect(await plugin.isSupported(const PostNotifications()), isTrue);
    });

    test('returns false for unregistered permissions', () async {
      expect(await plugin.isSupported(const ReadContacts()), isFalse);
      expect(await plugin.isSupported(const WriteContacts()), isFalse);
      expect(await plugin.isSupported(const ReadCalendar()), isFalse);
      expect(await plugin.isSupported(const SendSms()), isFalse);
      expect(await plugin.isSupported(const BluetoothConnect()), isFalse);
    });
  });

  group('openAppSettings()', () {
    test('returns false on web', () async {
      final result = await plugin.openAppSettings();
      expect(result, isFalse);
      expect(mockApi.calls, ['openAppSettings']);
    });
  });

  group('checkLocationAccuracy()', () {
    test('returns precise when geolocation is granted', () async {
      mockApi.queryResults = {'geolocation': 'granted'};
      final result = await plugin.checkLocationAccuracy();
      expect(result, LocationAccuracyStatus.precise);
    });

    test('returns notApplicable when geolocation is not granted', () async {
      mockApi.queryResults = {'geolocation': 'prompt'};
      final result = await plugin.checkLocationAccuracy();
      expect(result, LocationAccuracyStatus.notApplicable);
    });

    test('returns notApplicable when API unavailable', () async {
      mockApi.queryResults = {'geolocation': null};
      final result = await plugin.checkLocationAccuracy();
      expect(result, LocationAccuracyStatus.notApplicable);
    });
  });

  group('VersionedPermission resolution', () {
    test('resolves images() to ReadMediaImages (registered on web)', () async {
      mockApi.queryResults = {'camera': 'granted'};
      // VersionedPermission.images() has ReadMediaImages as first variant.
      // ReadMediaImages is NOT in web registry, so it should fall through.
      final perm = VersionedPermission.images();
      final result = await plugin.check(perm);
      // ReadMediaImages/ReadExternalStorage are storage permissions — not
      // registered on web, so should be notApplicable.
      expect(result, PermissionGrant.notApplicable);
    });
  });

  group('Registry coverage', () {
    test('exactly 5 permission types are registered', () {
      expect(webPermissionMapping.length, 5);
    });

    test('Android/iOS-only permissions return notApplicable', () async {
      final unsupported = <Permission>[
        const ReadContacts(),
        const WriteContacts(),
        const ReadCalendar(),
        const WriteCalendar(),
        const SendSms(),
        const ReadSms(),
        const ReadPhoneState(),
        const MakeCalls(),
        const BluetoothConnect(),
        const BodySensors(),
        const BackgroundLocation(),
        const DefaultSmsApp(),
        const BatteryOptimizationExemption(),
        const HealthAccess(),
        const AppTrackingTransparency(),
        const SpeechRecognition(),
      ];

      for (final permission in unsupported) {
        final result = await plugin.check(permission);
        expect(
          result,
          PermissionGrant.notApplicable,
          reason: '${permission.identifier} should be notApplicable on web',
        );
      }
    });
  });
}
