import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';

import 'package:simple_permissions_example/main.dart';

void main() {
  testWidgets('renders demo title and action buttons', (
    WidgetTester tester,
  ) async {
    await SimplePermissionsNative.initialize();
    await tester.pumpWidget(const MyApp());

    expect(find.text('Simple Permissions Demo'), findsOneWidget);
    expect(find.text('Single permissions'), findsOneWidget);
    expect(find.text('Batch & Intentions'), findsOneWidget);
    expect(find.text('Utilities'), findsOneWidget);
  });
}
