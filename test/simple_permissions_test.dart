import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions/simple_permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SimplePermissions', () {
    test('instance returns singleton', () {
      final a = SimplePermissions.instance;
      final b = SimplePermissions.instance;
      expect(identical(a, b), isTrue);
    });

    test('Intention.texting has SMS role', () {
      expect(Intention.texting.role, 'android.app.role.SMS');
    });

    test('Intention.calling has DIALER role', () {
      expect(Intention.calling.role, 'android.app.role.DIALER');
    });

    test('Intention.notifications has no role', () {
      expect(Intention.notifications.role, isNull);
    });

    test('Intention.texting has expected permissions', () {
      final perms = Intention.texting.permissions;
      expect(perms, contains('android.permission.SEND_SMS'));
      expect(perms, contains('android.permission.READ_SMS'));
      expect(perms, contains('android.permission.RECEIVE_SMS'));
      expect(perms, contains('android.permission.RECEIVE_MMS'));
    });

    test('Intention.fileAccess keeps compatibility permission set', () {
      final perms = Intention.fileAccess.permissions;
      expect(perms, contains('android.permission.READ_EXTERNAL_STORAGE'));
      expect(perms, contains('android.permission.READ_MEDIA_IMAGES'));
      expect(perms, contains('android.permission.READ_MEDIA_VIDEO'));
      expect(perms, contains('android.permission.READ_MEDIA_AUDIO'));
    });

    test('intention-first API methods are available', () {
      final checkMethod = SimplePermissions.instance.check;
      final requestMethod = SimplePermissions.instance.request;
      final detailedCheckMethod = SimplePermissions.instance.checkDetailed;
      final detailedRequestMethod = SimplePermissions.instance.requestDetailed;
      final rationaleMapMethod =
          SimplePermissions.instance.shouldShowRequestPermissionRationale;
      final rationaleMethod = SimplePermissions.instance.shouldShowRationale;
      final openSettingsMethod = SimplePermissions.instance.openAppSettings;

      expect(checkMethod, isA<Future<bool> Function(Intention)>());
      expect(requestMethod, isA<Future<bool> Function(Intention)>());
      expect(
        detailedCheckMethod,
        isA<Future<PermissionResult> Function(Intention)>(),
      );
      expect(
        detailedRequestMethod,
        isA<Future<PermissionResult> Function(Intention)>(),
      );
      expect(
        rationaleMapMethod,
        isA<Future<Map<String, bool>> Function(List<String>)>(),
      );
      expect(rationaleMethod, isA<Future<bool> Function(Intention)>());
      expect(openSettingsMethod, isA<Future<bool> Function()>());
    });

    test('PermissionResult aggregate flags are computed correctly', () {
      const result = PermissionResult(
        intention: Intention.contacts,
        roleStatus: PermissionStatus.notRequired,
        permissions: {
          'android.permission.READ_CONTACTS': PermissionStatus.granted,
          'android.permission.WRITE_CONTACTS': PermissionStatus.denied,
        },
      );

      expect(result.isRoleGranted, isTrue);
      expect(result.allPermissionsGranted, isFalse);
      expect(result.isFullyGranted, isFalse);
      expect(result.hasPermanentDenial, isFalse);
      expect(result.requiresSettings, isFalse);
    });

    test('PermissionResult detects permanent denial', () {
      const result = PermissionResult(
        intention: Intention.texting,
        roleStatus: PermissionStatus.denied,
        permissions: {
          'android.permission.SEND_SMS': PermissionStatus.permanentlyDenied,
        },
      );

      expect(result.hasPermanentDenial, isTrue);
      expect(result.requiresSettings, isTrue);
    });

    test('README usage flow compiles against current API', () async {
      // Intentionally not executed on a real device; this guards API drift.
      final api = SimplePermissions.instance;

      Future<void> sampleFlow() async {
        await SimplePermissions.initialize();

        final isTextingReady = await api.check(Intention.texting);
        if (!isTextingReady) {
          final granted = await api.request(Intention.texting);
          if (!granted) {
            return;
          }
        }

        final detailed = await api.requestDetailed(Intention.texting);
        if (detailed.requiresSettings) {
          await api.openAppSettings();
        }
      }

      expect(sampleFlow, isA<Future<void> Function()>());
    });
  });
}
