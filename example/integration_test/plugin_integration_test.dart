import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('check returns typed grant', (WidgetTester tester) async {
    await SimplePermissionsNative.initialize();
    final result = await SimplePermissionsNative.instance.check(ReadContacts());

    expect(result, isA<PermissionGrant>());
  });

  testWidgets('checkIntentionDetailed returns permission map', (
    WidgetTester tester,
  ) async {
    await SimplePermissionsNative.initialize();
    final result = await SimplePermissionsNative.instance.checkIntentionDetailed(
      Intention.texting,
    );

    expect(result, isA<PermissionResult>());
    expect(
      result.permissions.keys.map((p) => p.identifier),
      contains('default_sms_app'),
    );
  });
}
