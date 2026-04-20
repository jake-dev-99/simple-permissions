import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';

/// Scriptable fake platform: tests pre-populate [checkGrants] and
/// [requestGrants] to control exactly what `check` / `request` return,
/// and inspect [requestedPermissions] to verify the gate helpers only
/// requested what they should.
class _ScriptedPlatform extends SimplePermissionsPlatform {
  _ScriptedPlatform() : super();

  final Map<Permission, PermissionGrant> checkGrants = {};
  final Map<Permission, PermissionGrant> requestGrants = {};
  final List<Permission> requestedPermissions = [];
  final List<List<Permission>> requestAllCalls = [];

  @override
  Future<PermissionGrant> check(Permission p) async =>
      checkGrants[p] ?? PermissionGrant.denied;

  @override
  Future<PermissionGrant> request(Permission p) async {
    requestedPermissions.add(p);
    return requestGrants[p] ?? checkGrants[p] ?? PermissionGrant.denied;
  }

  @override
  Future<PermissionResult> checkAll(List<Permission> perms) async {
    return PermissionResult({
      for (final p in perms) p: checkGrants[p] ?? PermissionGrant.denied,
    });
  }

  @override
  Future<PermissionResult> requestAll(List<Permission> perms) async {
    requestAllCalls.add(List.of(perms));
    return PermissionResult({
      for (final p in perms)
        p: requestGrants[p] ?? checkGrants[p] ?? PermissionGrant.denied,
    });
  }

  @override
  Future<bool> isSupported(Permission p) async => true;

  @override
  Future<bool> openAppSettings() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ScriptedPlatform platform;

  setUp(() async {
    platform = _ScriptedPlatform();
    SimplePermissionsPlatform.instance = platform;
    SimplePermissionsNative.resetForTesting();
    await SimplePermissionsNative.initialize();
  });

  group('ensureGranted', () {
    test('satisfied grant short-circuits without requesting', () async {
      platform.checkGrants[const ReadContacts()] = PermissionGrant.granted;

      final grant = await SimplePermissionsNative.instance
          .ensureGranted(const ReadContacts());

      expect(grant, PermissionGrant.granted);
      expect(platform.requestedPermissions, isEmpty,
          reason: 'already-granted permissions should never re-prompt');
    });

    test('limited and provisional also short-circuit', () async {
      platform.checkGrants[const ReadMediaImages()] = PermissionGrant.limited;
      platform.checkGrants[const PostNotifications()] =
          PermissionGrant.provisional;

      final limited = await SimplePermissionsNative.instance
          .ensureGranted(const ReadMediaImages());
      final provisional = await SimplePermissionsNative.instance
          .ensureGranted(const PostNotifications());

      expect(limited, PermissionGrant.limited);
      expect(provisional, PermissionGrant.provisional);
      expect(platform.requestedPermissions, isEmpty);
    });

    test('denied grant triggers a request and returns the new grant',
        () async {
      platform.checkGrants[const ReadContacts()] = PermissionGrant.denied;
      platform.requestGrants[const ReadContacts()] = PermissionGrant.granted;

      final grant = await SimplePermissionsNative.instance
          .ensureGranted(const ReadContacts());

      expect(grant, PermissionGrant.granted);
      expect(platform.requestedPermissions, [const ReadContacts()]);
    });

    test('permanentlyDenied short-circuits to avoid a no-op prompt', () async {
      platform.checkGrants[const ReadContacts()] =
          PermissionGrant.permanentlyDenied;

      final grant = await SimplePermissionsNative.instance
          .ensureGranted(const ReadContacts());

      expect(grant, PermissionGrant.permanentlyDenied);
      expect(platform.requestedPermissions, isEmpty,
          reason: 'requesting a permanently-denied permission is a no-op '
              'on every platform — don\'t waste a round-trip');
    });

    test('notAvailable and notApplicable short-circuit', () async {
      platform.checkGrants[const ReadContacts()] = PermissionGrant.notAvailable;
      platform.checkGrants[const WriteContacts()] =
          PermissionGrant.notApplicable;

      final na = await SimplePermissionsNative.instance
          .ensureGranted(const ReadContacts());
      final napp = await SimplePermissionsNative.instance
          .ensureGranted(const WriteContacts());

      expect(na, PermissionGrant.notAvailable);
      expect(napp, PermissionGrant.notApplicable);
      expect(platform.requestedPermissions, isEmpty);
    });
  });

  group('ensureGrantedAll', () {
    test('only forwards non-satisfied, non-terminal permissions to requestAll',
        () async {
      platform.checkGrants[const ReadContacts()] = PermissionGrant.granted;
      platform.checkGrants[const WriteContacts()] = PermissionGrant.denied;
      platform.checkGrants[const ReadSms()] =
          PermissionGrant.permanentlyDenied;
      platform.checkGrants[const SendSms()] = PermissionGrant.notApplicable;
      platform.requestGrants[const WriteContacts()] = PermissionGrant.granted;

      final result = await SimplePermissionsNative.instance.ensureGrantedAll([
        const ReadContacts(),
        const WriteContacts(),
        const ReadSms(),
        const SendSms(),
      ]);

      expect(platform.requestAllCalls, hasLength(1));
      expect(platform.requestAllCalls.single, [const WriteContacts()],
          reason: 'granted stays, permanentlyDenied/notApplicable are '
              'terminal; only WriteContacts should be forwarded');

      expect(result.permissions[const ReadContacts()], PermissionGrant.granted);
      expect(
          result.permissions[const WriteContacts()], PermissionGrant.granted);
      expect(result.permissions[const ReadSms()],
          PermissionGrant.permanentlyDenied);
      expect(
          result.permissions[const SendSms()], PermissionGrant.notApplicable);
    });

    test('skips requestAll entirely when nothing is pending', () async {
      platform.checkGrants[const ReadContacts()] = PermissionGrant.granted;
      platform.checkGrants[const WriteContacts()] = PermissionGrant.granted;

      final result = await SimplePermissionsNative.instance.ensureGrantedAll([
        const ReadContacts(),
        const WriteContacts(),
      ]);

      expect(platform.requestAllCalls, isEmpty);
      expect(result.isFullyGranted, isTrue);
    });
  });

  group('ensureIntention', () {
    test('delegates to ensureGrantedAll with the intention\'s permissions',
        () async {
      for (final permission in Intention.camera.permissions) {
        platform.checkGrants[permission] = PermissionGrant.granted;
      }

      final result = await SimplePermissionsNative.instance
          .ensureIntention(Intention.camera);

      expect(result.isFullyGranted, isTrue);
      expect(platform.requestAllCalls, isEmpty);
    });
  });

  group('guard', () {
    test('invokes action and returns its value when granted', () async {
      platform.checkGrants[const ReadContacts()] = PermissionGrant.granted;

      final result = await SimplePermissionsNative.instance.guard(
        const ReadContacts(),
        () async => 'contacts',
      );

      expect(result, 'contacts');
    });

    test('returns null without invoking action when denied', () async {
      platform.checkGrants[const ReadContacts()] = PermissionGrant.denied;
      platform.requestGrants[const ReadContacts()] = PermissionGrant.denied;
      var actionRan = false;

      final result = await SimplePermissionsNative.instance.guard(
        const ReadContacts(),
        () async {
          actionRan = true;
          return 'contacts';
        },
      );

      expect(result, isNull);
      expect(actionRan, isFalse);
    });

    test('returns null and skips action when permanentlyDenied', () async {
      platform.checkGrants[const ReadContacts()] =
          PermissionGrant.permanentlyDenied;
      var actionRan = false;

      final result = await SimplePermissionsNative.instance.guard(
        const ReadContacts(),
        () async {
          actionRan = true;
          return 1;
        },
      );

      expect(result, isNull);
      expect(actionRan, isFalse);
      expect(platform.requestedPermissions, isEmpty);
    });
  });

  group('guardAll', () {
    test('runs action when every permission ends up satisfied', () async {
      platform.checkGrants[const ReadContacts()] = PermissionGrant.granted;
      platform.checkGrants[const WriteContacts()] = PermissionGrant.denied;
      platform.requestGrants[const WriteContacts()] = PermissionGrant.granted;

      final result =
          await SimplePermissionsNative.instance.guardAll(const [
        ReadContacts(),
        WriteContacts(),
      ], () async => 42);

      expect(result, 42);
    });

    test('returns null when any permission is not satisfied', () async {
      platform.checkGrants[const ReadContacts()] = PermissionGrant.granted;
      platform.checkGrants[const WriteContacts()] = PermissionGrant.denied;
      platform.requestGrants[const WriteContacts()] = PermissionGrant.denied;
      var actionRan = false;

      final result = await SimplePermissionsNative.instance.guardAll(
        const [ReadContacts(), WriteContacts()],
        () async {
          actionRan = true;
          return 42;
        },
      );

      expect(result, isNull);
      expect(actionRan, isFalse);
    });
  });

  group('guardIntention', () {
    test('runs action when the intention is fully satisfied', () async {
      for (final permission in Intention.camera.permissions) {
        platform.checkGrants[permission] = PermissionGrant.granted;
      }

      final result = await SimplePermissionsNative.instance
          .guardIntention(Intention.camera, () async => 'camera-ready');

      expect(result, 'camera-ready');
    });

    test('returns null and skips action when intention is not satisfied',
        () async {
      // Leave the camera intention's permissions at their default denied.
      platform.requestGrants.clear();
      var actionRan = false;

      final result = await SimplePermissionsNative.instance.guardIntention(
        Intention.camera,
        () async {
          actionRan = true;
          return 'camera-ready';
        },
      );

      expect(result, isNull);
      expect(actionRan, isFalse);
    });
  });
}
