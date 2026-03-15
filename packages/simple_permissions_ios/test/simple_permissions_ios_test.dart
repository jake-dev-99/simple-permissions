import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions_ios/simple_permissions_ios.dart';
import 'package:simple_permissions_ios/src/ios_permission_registry.dart';
import 'package:simple_permissions_ios/src/permissions_ios_api.dart';
import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

// =============================================================================
// Mock API — records calls, returns configurable wire values
// =============================================================================

class MockPermissionsIosApi implements PermissionsIosApi {
  final List<({String method, String? identifier})> log = [];

  /// Wire value returned by [checkPermission].
  String checkResult = 'granted';

  /// Wire value returned by [requestPermission].
  String requestResult = 'granted';

  /// Value returned by [openAppSettings].
  bool openSettingsResult = true;

  /// Wire value returned by [checkLocationAccuracy].
  String locationAccuracyResult = 'notApplicable';

  @override
  Future<String> checkPermission(String identifier) async {
    log.add((method: 'checkPermission', identifier: identifier));
    return checkResult;
  }

  @override
  Future<String> requestPermission(String identifier) async {
    log.add((method: 'requestPermission', identifier: identifier));
    return requestResult;
  }

  @override
  Future<bool> openAppSettings() async {
    log.add((method: 'openAppSettings', identifier: null));
    return openSettingsResult;
  }

  @override
  Future<String> checkLocationAccuracy() async {
    log.add((method: 'checkLocationAccuracy', identifier: null));
    return locationAccuracyResult;
  }
}

void main() {
  late SimplePermissionsIos plugin;
  late MockPermissionsIosApi mockApi;

  setUp(() {
    mockApi = MockPermissionsIosApi();
    plugin = SimplePermissionsIos(api: mockApi);
  });

  // ===========================================================================
  // Plugin registration
  // ===========================================================================

  group('SimplePermissionsIos', () {
    test('extends SimplePermissionsPlatform', () {
      expect(plugin, isA<SimplePermissionsPlatform>());
    });

    test('initialize preserves the platform interface contract', () async {
      await expectLater(plugin.initialize(), completes);
    });

    test('registerWith sets platform instance', () {
      SimplePermissionsIos.registerWith();
      expect(
        SimplePermissionsPlatform.instance,
        isA<SimplePermissionsIos>(),
      );
    });
  });

  // ===========================================================================
  // v2 API — check
  // ===========================================================================

  group('check()', () {
    test('routes registered permission through API with correct identifier',
        () async {
      mockApi.checkResult = 'granted';
      final result = await plugin.check(const ReadContacts());

      expect(result, PermissionGrant.granted);
      expect(mockApi.log, hasLength(1));
      expect(mockApi.log.first.method, 'checkPermission');
      expect(mockApi.log.first.identifier, 'read_contacts');
    });

    test('routes camera through API', () async {
      mockApi.checkResult = 'denied';
      final result = await plugin.check(const CameraAccess());

      expect(result, PermissionGrant.denied);
      expect(mockApi.log.first.identifier, 'camera_access');
    });

    test('routes microphone through API', () async {
      mockApi.checkResult = 'permanentlyDenied';
      final result = await plugin.check(const RecordAudio());

      expect(result, PermissionGrant.permanentlyDenied);
      expect(mockApi.log.first.identifier, 'record_audio');
    });

    test('routes photo library through API', () async {
      mockApi.checkResult = 'limited';
      final result = await plugin.check(const ReadMediaImages());

      expect(result, PermissionGrant.limited);
      expect(mockApi.log.first.identifier, 'read_media_images');
    });

    test('routes notifications through API', () async {
      mockApi.checkResult = 'provisional';
      final result = await plugin.check(const PostNotifications());

      expect(result, PermissionGrant.provisional);
      expect(mockApi.log.first.identifier, 'post_notifications');
    });

    test('routes location through API', () async {
      mockApi.checkResult = 'granted';
      final result = await plugin.check(const FineLocation());

      expect(result, PermissionGrant.granted);
      expect(mockApi.log.first.identifier, 'fine_location');
    });

    test('routes background location through API', () async {
      mockApi.checkResult = 'restricted';
      final result = await plugin.check(const BackgroundLocation());

      expect(result, PermissionGrant.restricted);
      expect(mockApi.log.first.identifier, 'background_location');
    });

    test('routes calendar through API', () async {
      mockApi.checkResult = 'granted';
      final result = await plugin.check(const ReadCalendar());

      expect(result, PermissionGrant.granted);
      expect(mockApi.log.first.identifier, 'read_calendar');
    });

    test('routes reminders through API', () async {
      mockApi.checkResult = 'granted';
      final result = await plugin.check(const ReadReminders());

      expect(result, PermissionGrant.granted);
      expect(mockApi.log.first.identifier, 'read_reminders');
    });

    test('routes bluetooth through API', () async {
      mockApi.checkResult = 'granted';
      final result = await plugin.check(const BluetoothScan());

      expect(result, PermissionGrant.granted);
      expect(mockApi.log.first.identifier, 'bluetooth_scan');
    });

    test('routes speech through API', () async {
      mockApi.checkResult = 'denied';
      final result = await plugin.check(const SpeechRecognition());

      expect(result, PermissionGrant.denied);
      expect(mockApi.log.first.identifier, 'speech_recognition');
    });

    test('routes health through API', () async {
      mockApi.checkResult = 'notAvailable';
      final result = await plugin.check(const ReadHealth());

      expect(result, PermissionGrant.notAvailable);
      expect(mockApi.log.first.identifier, 'read_health');
    });

    test('routes body sensors through API', () async {
      mockApi.checkResult = 'granted';
      final result = await plugin.check(const BodySensors());

      expect(result, PermissionGrant.granted);
      expect(mockApi.log.first.identifier, 'body_sensors');
    });

    test('routes activity recognition through API', () async {
      mockApi.checkResult = 'permanentlyDenied';
      final result = await plugin.check(const ActivityRecognition());

      expect(result, PermissionGrant.permanentlyDenied);
      expect(mockApi.log.first.identifier, 'activity_recognition');
    });

    test('routes app tracking transparency through API', () async {
      mockApi.checkResult = 'denied';
      final result = await plugin.check(const AppTrackingTransparency());

      expect(result, PermissionGrant.denied);
      expect(mockApi.log.first.identifier, 'app_tracking_transparency');
    });

    test(
        'returns notApplicable for Android-only permissions without calling API',
        () async {
      // Android SMS/telephony/phone concepts — not applicable on iOS
      final androidOnly = <Permission>[
        const SendSms(),
        const ReadSms(),
        const ReceiveSms(),
        const ReceiveMms(),
        const MakeCalls(),
        const AnswerCalls(),
        const ReadPhoneState(),
        const ReadPhoneNumbers(),
        const ReadCallLog(),
        const WriteCallLog(),
        const ReadExternalStorage(),
      ];

      for (final perm in androidOnly) {
        final result = await plugin.check(perm);
        expect(
          result,
          PermissionGrant.notApplicable,
          reason: '${perm.runtimeType} should be notApplicable on iOS',
        );
      }

      expect(mockApi.log, isEmpty,
          reason: 'No API calls should be made for Android-only permissions');
    });
  });

  // ===========================================================================
  // v2 API — request
  // ===========================================================================

  group('request()', () {
    test('routes registered permission through API with correct identifier',
        () async {
      mockApi.requestResult = 'granted';
      final result = await plugin.request(const WriteContacts());

      expect(result, PermissionGrant.granted);
      expect(mockApi.log, hasLength(1));
      expect(mockApi.log.first.method, 'requestPermission');
      expect(mockApi.log.first.identifier, 'write_contacts');
    });

    test('returns notApplicable for unregistered permissions', () async {
      final result = await plugin.request(const SendSms());

      expect(result, PermissionGrant.notApplicable);
      expect(mockApi.log, isEmpty);
    });
  });

  // ===========================================================================
  // v2 API — isSupported
  // ===========================================================================

  group('isSupported()', () {
    test('returns true for registered permissions', () {
      expect(plugin.isSupported(const ReadContacts()), isTrue);
      expect(plugin.isSupported(const CameraAccess()), isTrue);
      expect(plugin.isSupported(const PostNotifications()), isTrue);
      expect(plugin.isSupported(const FineLocation()), isTrue);
      expect(plugin.isSupported(const ReadCalendar()), isTrue);
      expect(plugin.isSupported(const ReadReminders()), isTrue);
      expect(plugin.isSupported(const BluetoothConnect()), isTrue);
      expect(plugin.isSupported(const SpeechRecognition()), isTrue);
      expect(plugin.isSupported(const ReadHealth()), isTrue);
      expect(plugin.isSupported(const BodySensors()), isTrue);
      expect(plugin.isSupported(const AppTrackingTransparency()), isTrue);
    });

    test('returns false for Android-only permissions', () {
      expect(plugin.isSupported(const SendSms()), isFalse);
      expect(plugin.isSupported(const MakeCalls()), isFalse);
      expect(plugin.isSupported(const ReadPhoneState()), isFalse);
      expect(plugin.isSupported(const ReadExternalStorage()), isFalse);
    });
  });

  // ===========================================================================
  // v2 API — openAppSettings
  // ===========================================================================

  group('openAppSettings()', () {
    test('delegates to API and returns result', () async {
      mockApi.openSettingsResult = true;
      final result = await plugin.openAppSettings();

      expect(result, isTrue);
      expect(mockApi.log, hasLength(1));
      expect(mockApi.log.first.method, 'openAppSettings');
    });

    test('returns false when API returns false', () async {
      mockApi.openSettingsResult = false;
      expect(await plugin.openAppSettings(), isFalse);
    });
  });

  group('checkLocationAccuracy()', () {
    test('maps precise', () async {
      mockApi.locationAccuracyResult = 'precise';
      expect(
        await plugin.checkLocationAccuracy(),
        LocationAccuracyStatus.precise,
      );
    });

    test('maps reduced', () async {
      mockApi.locationAccuracyResult = 'reduced';
      expect(
        await plugin.checkLocationAccuracy(),
        LocationAccuracyStatus.reduced,
      );
    });

    test('maps none', () async {
      mockApi.locationAccuracyResult = 'none';
      expect(
        await plugin.checkLocationAccuracy(),
        LocationAccuracyStatus.none,
      );
    });

    test('maps notAvailable', () async {
      mockApi.locationAccuracyResult = 'notAvailable';
      expect(
        await plugin.checkLocationAccuracy(),
        LocationAccuracyStatus.notAvailable,
      );
    });
  });

  // ===========================================================================
  // VersionedPermission resolution
  // ===========================================================================

  group('VersionedPermission resolution on iOS', () {
    test('resolves images() to ReadMediaImages and routes through API',
        () async {
      mockApi.checkResult = 'granted';
      final result = await plugin.check(VersionedPermission.images());

      expect(result, PermissionGrant.granted);
      expect(mockApi.log, hasLength(1));
      expect(mockApi.log.first.identifier, 'read_media_images');
    });

    test('resolves video() to ReadMediaVideo', () async {
      mockApi.checkResult = 'limited';
      final result = await plugin.check(VersionedPermission.video());

      expect(result, PermissionGrant.limited);
      expect(mockApi.log.first.identifier, 'read_media_video');
    });

    test(
        'resolves audio() — falls back to ReadMediaAudio (not registered on iOS)',
        () async {
      mockApi.checkResult = 'granted';
      // VersionedPermission.audio() has only API-constrained variants.
      // Falls back to first variant: ReadMediaAudio (minApiLevel: 33).
      // ReadMediaAudio has no iOS handler → notApplicable, no API call.
      final result = await plugin.check(VersionedPermission.audio());

      expect(result, PermissionGrant.notApplicable);
      expect(mockApi.log, isEmpty);
    });
  });

  // ===========================================================================
  // Wire parsing — all 8 PermissionGrant values
  // ===========================================================================

  group('Wire value parsing', () {
    final grantWireMap = <String, PermissionGrant>{
      'granted': PermissionGrant.granted,
      'denied': PermissionGrant.denied,
      'permanentlyDenied': PermissionGrant.permanentlyDenied,
      'restricted': PermissionGrant.restricted,
      'limited': PermissionGrant.limited,
      'notApplicable': PermissionGrant.notApplicable,
      'notAvailable': PermissionGrant.notAvailable,
      'provisional': PermissionGrant.provisional,
    };

    for (final entry in grantWireMap.entries) {
      test('parses "${entry.key}" to ${entry.value}', () async {
        mockApi.checkResult = entry.key;
        final result = await plugin.check(const ReadContacts());

        expect(
          result,
          entry.value,
          reason: 'Wire value "${entry.key}" should parse to ${entry.value}',
        );
      });
    }

    test('defaults to denied for unknown wire values', () async {
      mockApi.checkResult = 'some_unknown_value';
      final result = await plugin.check(const ReadContacts());
      expect(result, PermissionGrant.denied);
    });
  });

  // ===========================================================================
  // Registry coverage — ensure all 23 types are mapped
  // ===========================================================================

  group('iOS registry coverage', () {
    final registeredPermissions = <Permission>[
      const ReadContacts(),
      const WriteContacts(),
      const CameraAccess(),
      const RecordAudio(),
      const ReadMediaImages(),
      const ReadMediaVideo(),
      const PostNotifications(),
      const CoarseLocation(),
      const FineLocation(),
      const BackgroundLocation(),
      const ReadCalendar(),
      const WriteCalendar(),
      const ReadReminders(),
      const WriteReminders(),
      const BluetoothConnect(),
      const BluetoothScan(),
      const BluetoothAdvertise(),
      const SpeechRecognition(),
      const ReadHealth(),
      const WriteHealth(),
      const BodySensors(),
      const ActivityRecognition(),
      const AppTrackingTransparency(),
    ];

    for (final perm in registeredPermissions) {
      test('${perm.runtimeType} is registered and routable', () async {
        mockApi.checkResult = 'granted';
        final result = await plugin.check(perm);

        expect(result, PermissionGrant.granted);
        expect(mockApi.log, hasLength(1),
            reason: '${perm.runtimeType} should make exactly one API call');
        expect(mockApi.log.first.identifier, perm.identifier,
            reason:
                '${perm.runtimeType} should use its identifier "${perm.identifier}"');
      });
    }

    test('exactly 23 permissions are registered', () {
      var count = 0;
      for (final perm in registeredPermissions) {
        if (plugin.isSupported(perm)) count++;
      }
      expect(count, 23);
    });

    test('Dart and Swift registries stay aligned', () async {
      final swiftRegistry = await File(
        'ios/Classes/PermissionRegistry.swift',
      ).readAsString();
      final swiftIdentifiers = _extractSwiftIdentifiers(swiftRegistry);
      final dartIdentifiers = registeredPermissions
          .where((perm) => isIosPermissionRegistered(perm.runtimeType))
          .map((perm) => perm.identifier)
          .toSet();

      expect(swiftIdentifiers, dartIdentifiers);
    });
  });
}

Set<String> _extractSwiftIdentifiers(String source) {
  final matches = RegExp(r'"([^"]+)":\s*[A-Za-z]+PermissionHandler').allMatches(
    source,
  );
  return matches.map((match) => match.group(1)!).toSet();
}
