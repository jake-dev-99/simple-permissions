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
  });
}
