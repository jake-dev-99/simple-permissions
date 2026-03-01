import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';

import 'package:simple_permissions_example/main.dart';

void main() {
  testWidgets('renders example title and permissions header', (
    WidgetTester tester,
  ) async {
    await SimplePermissionsNative.initialize();
    await tester.pumpWidget(const MyApp());

    expect(find.text('Simple Permissions Example'), findsOneWidget);
    expect(find.text('Permissions:'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
