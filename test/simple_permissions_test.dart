import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SimplePermissionsNative initialization', () {
    test('instance returns singleton', () {
      final a = SimplePermissionsNative.instance;
      final b = SimplePermissionsNative.instance;
      expect(identical(a, b), isTrue);
    });

    test('throws StateError if not initialized', () async {
      SimplePermissionsNative.resetForTesting();
      expect(
        () => SimplePermissionsNative.instance.check(ReadContacts()),
        throwsA(isA<StateError>()),
      );
      await SimplePermissionsNative.initialize();
    });

    test('initialize marks API initialized', () async {
      SimplePermissionsNative.resetForTesting();
      expect(SimplePermissionsNative.isInitialized, isFalse);
      await SimplePermissionsNative.initialize();
      expect(SimplePermissionsNative.isInitialized, isTrue);
    });
  });

  group('v2 permission API', () {
    setUpAll(() async {
      await SimplePermissionsNative.initialize();
    });

    test('check returns a PermissionGrant', () async {
      final grant =
          await SimplePermissionsNative.instance.check(ReadContacts());
      expect(grant, isA<PermissionGrant>());
    });

    test('request returns a PermissionGrant', () async {
      final grant =
          await SimplePermissionsNative.instance.request(ReadContacts());
      expect(grant, isA<PermissionGrant>());
    });

    test('checkAll returns PermissionResult', () async {
      final result = await SimplePermissionsNative.instance.checkAll([
        ReadContacts(),
        WriteContacts(),
      ]);

      expect(result, isA<PermissionResult>());
      expect(result.permissions, hasLength(2));
      expect(
        result.permissions.keys.map((p) => p.identifier),
        containsAll(['read_contacts', 'write_contacts']),
      );
    });

    test('requestAll returns PermissionResult', () async {
      final result = await SimplePermissionsNative.instance.requestAll([
        PostNotifications(),
      ]);

      expect(result, isA<PermissionResult>());
      expect(result.permissions, hasLength(1));
      expect(result.permissions.keys.first.identifier, 'post_notifications');
    });

    test('isSupported returns bool', () async {
      final supported =
          SimplePermissionsNative.instance.isSupported(ReadContacts());
      expect(supported, isA<bool>());
    });

    test('noop platform marks permissions notApplicable', () async {
      final probes = <Permission>[
        ReadContacts(),
        WriteContacts(),
        SendSms(),
        ReadSms(),
        ReceiveSms(),
        DefaultSmsApp(),
        ReadPhoneState(),
        ReadPhoneNumbers(),
        MakeCalls(),
        AnswerCalls(),
        PostNotifications(),
        ReadMediaImages(),
        ReadMediaVideo(),
        ReadMediaAudio(),
        ReadExternalStorage(),
        BatteryOptimizationExemption(),
      ];

      for (final permission in probes) {
        final grant = await SimplePermissionsNative.instance.check(permission);
        expect(
          grant,
          PermissionGrant.notApplicable,
          reason:
              '${permission.identifier} should be explicit on noop platform',
        );
      }
    });
  });

  group('Intention API', () {
    setUpAll(() async {
      await SimplePermissionsNative.initialize();
    });

    test('checkIntention returns bool', () async {
      final ready = await SimplePermissionsNative.instance.checkIntention(
        Intention.texting,
      );
      expect(ready, isFalse);
    });

    test('requestIntention returns bool', () async {
      final granted = await SimplePermissionsNative.instance.requestIntention(
        Intention.contacts,
      );
      expect(granted, isFalse);
    });

    test('checkIntentionDetailed returns PermissionResult', () async {
      final result =
          await SimplePermissionsNative.instance.checkIntentionDetailed(
        Intention.calling,
      );
      expect(result, isA<PermissionResult>());
      expect(result.permissions, isNotEmpty);
      expect(result.hasUnsupported, isTrue);
    });

    test('requestIntentionDetailed returns PermissionResult', () async {
      final result =
          await SimplePermissionsNative.instance.requestIntentionDetailed(
        Intention.notifications,
      );
      expect(result, isA<PermissionResult>());
      expect(result.permissions, hasLength(1));
      expect(result.hasUnsupported, isTrue);
    });

    test('built-in intentions expose permissions', () {
      final builtIns = <Intention>[
        Intention.texting,
        Intention.calling,
        Intention.defaultSmsRole,
        Intention.defaultDialerRole,
        Intention.textingWithDefaultSmsRole,
        Intention.callingWithDefaultDialerRole,
        Intention.contacts,
        Intention.device,
        Intention.mediaImages,
        Intention.mediaVideo,
        Intention.mediaAudio,
        Intention.mediaVisual,
        Intention.notifications,
        Intention.location,
        Intention.camera,
        Intention.microphone,
      ];

      for (final intention in builtIns) {
        expect(intention.permissions, isNotEmpty);
      }
    });

    test('Intention.combine removes duplicate permissions', () {
      final combined = Intention.combine('comms', [
        Intention.textingWithDefaultSmsRole,
        Intention.callingWithDefaultDialerRole,
        Intention.device,
      ]);

      final identifiers =
          combined.permissions.map((p) => p.identifier).toList();
      expect(identifiers.toSet().length, identifiers.length);
    });

    test('role-free presets do not include app roles', () {
      expect(
        Intention.texting.permissions.any((p) => p is DefaultSmsApp),
        isFalse,
      );
      expect(
        Intention.calling.permissions.any((p) => p is DefaultDialerApp),
        isFalse,
      );
    });
  });

  group('openAppSettings', () {
    test('returns bool', () async {
      await SimplePermissionsNative.initialize();
      final result = await SimplePermissionsNative.instance.openAppSettings();
      expect(result, isA<bool>());
    });
  });
}
