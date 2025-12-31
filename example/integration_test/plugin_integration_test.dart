import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:simple_permissions/simple_permissions.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('checkPermissions returns map', (WidgetTester tester) async {
    await SimplePermissions.initialize();
    final result = await SimplePermissions.instance.checkPermissions([
      'android.permission.READ_SMS',
    ]);
    expect(result, isA<Map<String, bool>>());
    expect(result.keys, contains('android.permission.READ_SMS'));
  });
}
