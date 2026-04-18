// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:simple_permissions_platform_interface/darwin_permission_utils.dart';
import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

void main() {
  final originalInstance = SimplePermissionsPlatform.instance;

  group('SimplePermissionsPlatform', () {
    tearDown(() {
      SimplePermissionsPlatform.instance = originalInstance;
    });

    test('default instance is noop', () {
      expect(originalInstance, isNotNull);
    });

    test('setting instance with correct token succeeds', () {
      final custom = _GoodPlatform();
      SimplePermissionsPlatform.instance = custom;
      expect(SimplePermissionsPlatform.instance, same(custom));
    });

    test('MockPlatformInterfaceMixin bypasses token check', () {
      final mock = _MockPlatform();
      SimplePermissionsPlatform.instance = mock;
      expect(SimplePermissionsPlatform.instance, same(mock));
    });
  });

  // ===========================================================================
  // v2 API — Noop platform behavior
  // ===========================================================================

  group('Noop platform v2 behavior', () {
    final noop = originalInstance;

    test('check returns notApplicable for all permission types', () async {
      final permissions = <Permission>[
        const ReadContacts(),
        const WriteContacts(),
        const CameraAccess(),
        const FineLocation(),
        const PostNotifications(),
        const SendSms(),
        const DefaultSmsApp(),
        const BatteryOptimizationExemption(),
        const ManageExternalStorage(),
        const RecordAudio(),
        const ReadCalendar(),
        const ReadReminders(),
        const BluetoothConnect(),
        const SpeechRecognition(),
        const BodySensors(),
        const NearbyWifiDevices(),
        const AppTrackingTransparency(),
        const HealthAccess(),
      ];

      for (final p in permissions) {
        final result = await noop.check(p);
        expect(
          result,
          PermissionGrant.notApplicable,
          reason: '${p.identifier} should be explicit on noop platform',
        );
      }
    });

    test('request returns notApplicable for all permission types', () async {
      final result = await noop.request(const ReadContacts());
      expect(result, PermissionGrant.notApplicable);
    });

    test('checkAll returns all unsupported', () async {
      final result = await noop.checkAll([
        const ReadContacts(),
        const WriteContacts(),
        const PostNotifications(),
      ]);

      expect(result, isA<PermissionResult>());
      expect(result.permissions, hasLength(3));
      expect(result.isFullyGranted, isFalse);
      expect(result.hasUnsupported, isTrue);
      expect(result.unsupported, hasLength(3));
    });

    test('requestAll returns all unsupported', () async {
      final result = await noop.requestAll([
        const CameraAccess(),
        const RecordAudio(),
      ]);

      expect(result.isFullyGranted, isFalse);
      expect(result.hasDenial, isFalse);
      expect(result.hasUnsupported, isTrue);
    });

    test('isSupported returns false for all permissions', () async {
      expect(await noop.isSupported(const ReadContacts()), isFalse);
      expect(await noop.isSupported(const AppTrackingTransparency()), isFalse);
      expect(await noop.isSupported(const DefaultSmsApp()), isFalse);
    });

    test('openAppSettings returns false', () async {
      expect(await noop.openAppSettings(), isFalse);
    });

    test('checkLocationAccuracy returns notApplicable', () async {
      expect(
        await noop.checkLocationAccuracy(),
        LocationAccuracyStatus.notApplicable,
      );
    });

    test('VersionedPermission check returns notApplicable', () async {
      final result = await noop.check(const VersionedPermission.images());
      expect(result, PermissionGrant.notApplicable);
    });
  });

  // ===========================================================================
  // Permission sealed class hierarchy
  // ===========================================================================

  group('Permission sealed classes', () {
    test('all concrete classes are const-constructible', () {
      const permissions = <Permission>[
        // Camera
        CameraAccess(),
        // Location
        CoarseLocation(), FineLocation(), BackgroundLocation(),
        // Contacts
        ReadContacts(), WriteContacts(),
        // Storage
        ReadExternalStorage(), ReadMediaImages(), ReadMediaVideo(),
        ReadMediaAudio(), ReadMediaVisualUserSelected(),
        // Phone
        ReadPhoneState(), ReadPhoneNumbers(), MakeCalls(), AnswerCalls(),
        ManageOwnCalls(), ReadCallLog(), WriteCallLog(),
        ReadVoicemail(), AddVoicemail(), AcceptHandover(),
        // Messaging
        SendSms(), ReadSms(), ReceiveSms(), ReceiveMms(), ReceiveWapPush(),
        // Bluetooth
        BluetoothConnect(), BluetoothScan(), BluetoothAdvertise(),
        BluetoothLegacy(), BluetoothAdminLegacy(),
        // Calendar
        ReadCalendar(), WriteCalendar(), ReadReminders(), WriteReminders(),
        // Notification
        PostNotifications(),
        // Microphone
        RecordAudio(),
        // Sensor
        BodySensors(), ActivityRecognition(),
        BodySensorsBackground(), UwbRanging(),
        // System
        BatteryOptimizationExemption(), ScheduleExactAlarm(),
        RequestInstallPackages(), SystemAlertWindow(), ManageExternalStorage(),
        // Speech
        SpeechRecognition(),
        // Role
        DefaultSmsApp(), DefaultDialerApp(), DefaultBrowserApp(),
        DefaultAssistantApp(),
        // Wifi
        NearbyWifiDevices(),
        // Tracking
        AppTrackingTransparency(),
        // Health
        HealthAccess(),
      ];

      // Every permission has a non-empty identifier
      for (final p in permissions) {
        expect(p.identifier, isNotEmpty,
            reason: '$p should have an identifier');
      }

      // All identifiers are unique
      final identifiers = permissions.map((p) => p.identifier).toSet();
      expect(identifiers, hasLength(permissions.length),
          reason: 'All identifiers should be unique');
    });

    test('const identity equality', () {
      expect(const ReadContacts(), same(const ReadContacts()));
      expect(const ReadContacts(), isNot(same(const WriteContacts())));
      expect(const ReadContacts().hashCode, const ReadContacts().hashCode);
    });

    test('toString includes type and identifier', () {
      expect(
        const ReadContacts().toString(),
        contains('ReadContacts'),
      );
      expect(
        const ReadContacts().toString(),
        contains('read_contacts'),
      );
    });

    test('sealed class hierarchy is correct', () {
      expect(const CameraAccess(), isA<CameraPermission>());
      expect(const CameraAccess(), isA<Permission>());
      expect(const FineLocation(), isA<LocationPermission>());
      expect(const ReadContacts(), isA<ContactsPermission>());
      expect(const ReadMediaImages(), isA<StoragePermission>());
      expect(const SendSms(), isA<MessagingPermission>());
      expect(const ReadPhoneState(), isA<PhonePermission>());
      expect(const ReadVoicemail(), isA<PhonePermission>());
      expect(const BluetoothConnect(), isA<BluetoothPermission>());
      expect(const ReadCalendar(), isA<CalendarPermission>());
      expect(const ReadReminders(), isA<CalendarPermission>());
      expect(const PostNotifications(), isA<NotificationPermission>());
      expect(const RecordAudio(), isA<MicrophonePermission>());
      expect(const BodySensors(), isA<SensorPermission>());
      expect(const BodySensorsBackground(), isA<SensorPermission>());
      expect(const BatteryOptimizationExemption(), isA<SystemPermission>());
      expect(const SpeechRecognition(), isA<SpeechPermission>());
      expect(const DefaultSmsApp(), isA<AppRole>());
      expect(const NearbyWifiDevices(), isA<WifiPermission>());
      expect(const AppTrackingTransparency(), isA<TrackingPermission>());
      expect(const HealthAccess(), isA<HealthPermission>());
    });
  });

  // ===========================================================================
  // VersionedPermission
  // ===========================================================================

  group('VersionedPermission', () {
    test('factory constructors exist for all versioned pairs', () {
      const versioned = <VersionedPermission>[
        VersionedPermission.images(),
        VersionedPermission.video(),
        VersionedPermission.audio(),
        VersionedPermission.bluetoothConnect(),
        VersionedPermission.bluetoothScan(),
      ];

      for (final v in versioned) {
        expect(v.identifier, isNotEmpty);
        expect(v.variants, isNotEmpty);
        expect(v.variants.length, greaterThanOrEqualTo(2),
            reason: '${v.identifier} should have at least 2 variants');
      }
    });

    test('images() has correct variants', () {
      const v = VersionedPermission.images();
      expect(v.variants[0].permission, isA<ReadMediaImages>());
      expect(v.variants[0].minApiLevel, 33);
      expect(v.variants[1].permission, isA<ReadExternalStorage>());
      expect(v.variants[1].maxApiLevel, 32);
    });

    test('video() has correct variants', () {
      const v = VersionedPermission.video();
      expect(v.variants[0].permission, isA<ReadMediaVideo>());
      expect(v.variants[0].minApiLevel, 33);
      expect(v.variants[1].permission, isA<ReadExternalStorage>());
      expect(v.variants[1].maxApiLevel, 32);
    });

    test('audio() has correct variants', () {
      const v = VersionedPermission.audio();
      expect(v.variants[0].permission, isA<ReadMediaAudio>());
      expect(v.variants[0].minApiLevel, 33);
      expect(v.variants[1].permission, isA<ReadExternalStorage>());
      expect(v.variants[1].maxApiLevel, 32);
    });

    test('bluetoothConnect() has correct variants', () {
      const v = VersionedPermission.bluetoothConnect();
      expect(v.variants[0].permission, isA<BluetoothConnect>());
      expect(v.variants[0].minApiLevel, 31);
      expect(v.variants[1].permission, isA<BluetoothLegacy>());
      expect(v.variants[1].maxApiLevel, 30);
    });

    test('bluetoothScan() has correct variants', () {
      const v = VersionedPermission.bluetoothScan();
      expect(v.variants[0].permission, isA<BluetoothScan>());
      expect(v.variants[0].minApiLevel, 31);
      expect(v.variants[1].permission, isA<BluetoothAdminLegacy>());
      expect(v.variants[1].maxApiLevel, 30);
    });

    test('VersionedPermission extends Permission', () {
      expect(const VersionedPermission.images(), isA<Permission>());
    });
  });

  // ===========================================================================
  // PermissionResult
  // ===========================================================================

  group('PermissionResult', () {
    test('isFullyGranted when all granted', () {
      final result = PermissionResult({
        ReadContacts(): PermissionGrant.granted,
        WriteContacts(): PermissionGrant.granted,
      });
      expect(result.isFullyGranted, isTrue);
      expect(result.isReady, isTrue);
      expect(result.hasDenial, isFalse);
      expect(result.hasPermanentDenial, isFalse);
      expect(result.requiresSettings, isFalse);
      expect(result.denied, isEmpty);
    });

    test('isFullyGranted treats notApplicable as unsupported', () {
      final result = PermissionResult({
        SendSms(): PermissionGrant.notApplicable,
        ReadMediaImages(): PermissionGrant.limited,
        ReadContacts(): PermissionGrant.granted,
      });
      expect(result.isFullyGranted, isFalse);
      expect(result.isOperational, isFalse);
      expect(result.hasUnsupported, isTrue);
      expect(result.unsupported, [const SendSms()]);
    });

    test('isFullyGranted treats provisional as satisfied', () {
      final result = PermissionResult({
        PostNotifications(): PermissionGrant.provisional,
      });
      expect(result.isFullyGranted, isTrue);
    });

    test('isFullyGranted treats notAvailable as unsupported', () {
      final result = PermissionResult({
        PostNotifications(): PermissionGrant.notAvailable,
        ReadContacts(): PermissionGrant.granted,
      });
      expect(result.isFullyGranted, isFalse);
      expect(result.hasUnsupported, isTrue);
      expect(result.unsupported, [const PostNotifications()]);
    });

    test('restricted is treated as denial', () {
      final result = PermissionResult({
        ReadContacts(): PermissionGrant.restricted,
      });
      expect(result.isFullyGranted, isFalse);
      expect(result.hasDenial, isTrue);
      expect(result.denied, [const ReadContacts()]);
    });

    test('not fully granted when any denied', () {
      final result = PermissionResult({
        ReadContacts(): PermissionGrant.granted,
        WriteContacts(): PermissionGrant.denied,
      });
      expect(result.isFullyGranted, isFalse);
      expect(result.hasDenial, isTrue);
      expect(result.hasPermanentDenial, isFalse);
      expect(result.denied, [const WriteContacts()]);
    });

    test('detects permanent denial', () {
      final result = PermissionResult({
        ReadContacts(): PermissionGrant.permanentlyDenied,
        WriteContacts(): PermissionGrant.denied,
      });
      expect(result.isFullyGranted, isFalse);
      expect(result.hasPermanentDenial, isTrue);
      expect(result.requiresSettings, isTrue);
      expect(result.permanentlyDenied, [const ReadContacts()]);
      expect(result.denied, hasLength(2));
    });

    test('unavailable lists notAvailable permissions', () {
      final result = PermissionResult({
        PostNotifications(): PermissionGrant.notAvailable,
        ReadContacts(): PermissionGrant.granted,
      });
      expect(result.unavailable, [const PostNotifications()]);
    });

    test('isOperational mirrors strict readiness', () {
      final result = PermissionResult({
        ReadContacts(): PermissionGrant.granted,
        WriteContacts(): PermissionGrant.provisional,
      });
      expect(result.isOperational, isTrue);
    });

    test('subscript operator looks up grant', () {
      final result = PermissionResult({
        ReadContacts(): PermissionGrant.granted,
        WriteContacts(): PermissionGrant.denied,
      });
      expect(result[const ReadContacts()], PermissionGrant.granted);
      expect(result[const WriteContacts()], PermissionGrant.denied);
      expect(result[const CameraAccess()], isNull);
    });

    test('toString contains PermissionResult', () {
      final result = PermissionResult({
        ReadContacts(): PermissionGrant.granted,
      });
      expect(result.toString(), contains('PermissionResult'));
    });

    test('value equality and hashCode are stable for equivalent maps', () {
      final a = PermissionResult({
        ReadContacts(): PermissionGrant.granted,
        ReadMediaImages(): PermissionGrant.limited,
      });
      final b = PermissionResult({
        ReadMediaImages(): PermissionGrant.limited,
        ReadContacts(): PermissionGrant.granted,
      });

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('defensively copies input maps', () {
      final source = <Permission, PermissionGrant>{
        const ReadContacts(): PermissionGrant.granted,
      };
      final result = PermissionResult(source);
      source[const WriteContacts()] = PermissionGrant.denied;

      expect(result.permissions, hasLength(1));
      expect(
        () =>
            result.permissions[const WriteContacts()] = PermissionGrant.denied,
        throwsUnsupportedError,
      );
    });
  });

  group('Darwin permission utilities', () {
    test('permissionGrantFromDarwinWire maps all known wire values', () {
      expect(
        permissionGrantFromDarwinWire('granted'),
        PermissionGrant.granted,
      );
      expect(permissionGrantFromDarwinWire('denied'), PermissionGrant.denied);
      expect(
        permissionGrantFromDarwinWire('permanentlyDenied'),
        PermissionGrant.permanentlyDenied,
      );
      expect(
        permissionGrantFromDarwinWire('restricted'),
        PermissionGrant.restricted,
      );
      expect(permissionGrantFromDarwinWire('limited'), PermissionGrant.limited);
      expect(
        permissionGrantFromDarwinWire('notAvailable'),
        PermissionGrant.notAvailable,
      );
      expect(
        permissionGrantFromDarwinWire('provisional'),
        PermissionGrant.provisional,
      );
      expect(
        permissionGrantFromDarwinWire('notApplicable'),
        PermissionGrant.notApplicable,
      );
      expect(
          permissionGrantFromDarwinWire(null), PermissionGrant.notApplicable);
      expect(
        permissionGrantFromDarwinWire('unexpected'),
        PermissionGrant.denied,
      );
    });

    test('resolveVersionedForDarwin picks first registered variant', () {
      final resolved = resolveVersionedForDarwin(
        const VersionedPermission.images(),
        (type) => type == ReadExternalStorage,
      );
      expect(resolved, isA<ReadExternalStorage>());
    });

    test('resolveVersionedForDarwin returns original when none registered', () {
      final resolved = resolveVersionedForDarwin(
        const VersionedPermission.images(),
        (_) => false,
      );
      expect(resolved, isA<VersionedPermission>());
    });

    test('resolveVersionedForDarwin leaves non-versioned permissions untouched',
        () {
      final resolved = resolveVersionedForDarwin(
        const ReadContacts(),
        (_) => false,
      );
      expect(resolved, isA<ReadContacts>());
    });
  });

  // ===========================================================================
  // Intention
  // ===========================================================================

  group('Intention', () {
    test('built-in intentions have correct permission types', () {
      expect(
        Intention.texting.permissions,
        containsAll([
          isA<SendSms>(),
          isA<ReadSms>(),
          isA<ReceiveSms>(),
        ]),
      );

      expect(
        Intention.calling.permissions,
        containsAll([
          isA<MakeCalls>(),
          isA<AnswerCalls>(),
        ]),
      );

      expect(
        Intention.defaultSmsRole.permissions,
        equals([const DefaultSmsApp()]),
      );

      expect(
        Intention.defaultDialerRole.permissions,
        equals([const DefaultDialerApp()]),
      );

      expect(
        Intention.textingWithDefaultSmsRole.permissions,
        containsAll([isA<DefaultSmsApp>(), isA<SendSms>()]),
      );

      expect(
        Intention.callingWithDefaultDialerRole.permissions,
        containsAll([isA<DefaultDialerApp>(), isA<MakeCalls>()]),
      );

      expect(
        Intention.contacts.permissions,
        containsAll([isA<ReadContacts>(), isA<WriteContacts>()]),
      );

      expect(
        Intention.notifications.permissions,
        contains(isA<PostNotifications>()),
      );

      expect(
        Intention.location.permissions,
        containsAll([isA<FineLocation>(), isA<CoarseLocation>()]),
      );

      expect(
        Intention.camera.permissions,
        contains(isA<CameraAccess>()),
      );

      expect(
        Intention.microphone.permissions,
        contains(isA<RecordAudio>()),
      );
    });

    test('versioned intentions use VersionedPermission', () {
      expect(
        Intention.mediaImages.permissions,
        contains(isA<VersionedPermission>()),
      );
      expect(
        Intention.mediaVideo.permissions,
        contains(isA<VersionedPermission>()),
      );
      expect(
        Intention.mediaAudio.permissions,
        contains(isA<VersionedPermission>()),
      );
    });

    test('combine deduplicates permissions by identifier', () {
      final combined = Intention.combine('test', [
        Intention.contacts,
        Intention('also_contacts', [ReadContacts(), CameraAccess()]),
      ]);

      expect(combined.name, 'test');
      // ReadContacts appears in both but should only be included once
      final identifiers =
          combined.permissions.map((p) => p.identifier).toList();
      expect(
        identifiers.where((id) => id == 'read_contacts').length,
        1,
      );
      // But CameraAccess and WriteContacts should both be present
      expect(identifiers, contains('write_contacts'));
      expect(identifiers, contains('camera_access'));
    });

    test('custom Intention construction', () {
      final custom = Intention('my_feature', [
        CameraAccess(),
        RecordAudio(),
        FineLocation(),
      ]);
      expect(custom.name, 'my_feature');
      expect(custom.permissions, hasLength(3));
    });

    test('const-constructed Intentions have immutable permission lists', () {
      const custom = Intention('my_feature', [CameraAccess(), RecordAudio()]);
      expect(custom.permissions, hasLength(2));

      // Const lists are inherently unmodifiable.
      expect(
        () => (custom.permissions as List).add(const FineLocation()),
        throwsUnsupportedError,
      );
    });

    test('toString includes name and count', () {
      expect(
        Intention.texting.toString(),
        contains('texting'),
      );
    });
  });

  // ===========================================================================
  // PermissionGrant enum
  // ===========================================================================

  group('PermissionGrant', () {
    test('has 8 values', () {
      expect(PermissionGrant.values, hasLength(8));
    });

    test('has expected values', () {
      expect(
        PermissionGrant.values,
        containsAll([
          PermissionGrant.granted,
          PermissionGrant.denied,
          PermissionGrant.permanentlyDenied,
          PermissionGrant.restricted,
          PermissionGrant.limited,
          PermissionGrant.notApplicable,
          PermissionGrant.notAvailable,
          PermissionGrant.provisional,
        ]),
      );
    });
  });

  group('LocationAccuracyStatus', () {
    test('has expected values', () {
      expect(
        LocationAccuracyStatus.values,
        containsAll([
          LocationAccuracyStatus.precise,
          LocationAccuracyStatus.reduced,
          LocationAccuracyStatus.none,
          LocationAccuracyStatus.notApplicable,
          LocationAccuracyStatus.notAvailable,
        ]),
      );
    });
  });
}

class _GoodPlatform extends SimplePermissionsPlatform {
  _GoodPlatform() : super();

  // v2 API
  @override
  Future<PermissionGrant> check(Permission p) async => PermissionGrant.granted;
  @override
  Future<PermissionGrant> request(Permission p) async =>
      PermissionGrant.granted;
  @override
  Future<bool> isSupported(Permission p) async => true;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<LocationAccuracyStatus> checkLocationAccuracy() async =>
      LocationAccuracyStatus.precise;
}

class _MockPlatform extends SimplePermissionsPlatform
    with MockPlatformInterfaceMixin {
  // v2 API
  @override
  Future<PermissionGrant> check(Permission p) async => PermissionGrant.granted;
  @override
  Future<PermissionGrant> request(Permission p) async =>
      PermissionGrant.granted;
  @override
  Future<bool> isSupported(Permission p) async => true;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<LocationAccuracyStatus> checkLocationAccuracy() async =>
      LocationAccuracyStatus.precise;
}
