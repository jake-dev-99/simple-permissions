import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';

import 'package:simple_permissions_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const smokeIds = <String>[
    'read_contacts',
    'camera_access',
    'record_audio',
    'fine_location',
  ];

  Future<void> pumpHarness(WidgetTester tester) async {
    if (!SimplePermissionsNative.isInitialized) {
      await SimplePermissionsNative.initialize();
    }
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
  }

  Future<void> tapByKey(WidgetTester tester, String value) async {
    await tester.ensureVisible(find.byKey(Key(value)));
    await tester.tap(find.byKey(Key(value)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  final isAppleTarget = Platform.isIOS || Platform.isMacOS;

  testWidgets('smoke harness initializes and renders deterministic markers', (
    WidgetTester tester,
  ) async {
    await pumpHarness(tester);

    expect(find.byKey(const Key('initialized-status')), findsOneWidget);
    expect(find.textContaining('Initialized: true'), findsOneWidget);
    expect(find.byKey(const Key('location-accuracy-status')), findsOneWidget);

    for (final id in smokeIds) {
      expect(find.byKey(Key('permission-card-$id')), findsOneWidget);
      expect(find.byKey(Key('supported-$id')), findsOneWidget);
      expect(find.byKey(Key('check-result-$id')), findsOneWidget);
      expect(find.byKey(Key('request-result-$id')), findsOneWidget);
    }
  });

  testWidgets('check actions complete on supported Apple targets', (
    WidgetTester tester,
  ) async {
    await pumpHarness(tester);

    if (!isAppleTarget) {
      expect(find.textContaining('supported=false'), findsWidgets);
      return;
    }

    for (final id in smokeIds) {
      expect(find.text('supported=true'), findsWidgets);
      await tapByKey(tester, 'check-$id');
      final resultText = tester.widget<Text>(
        find.byKey(Key('check-result-$id')),
      );
      expect(resultText.data, isNotNull);
      expect(resultText.data, isNot(contains('pending')));
    }
  });

  testWidgets('request actions complete without channel failures', (
    WidgetTester tester,
  ) async {
    await pumpHarness(tester);

    if (!isAppleTarget) {
      final supported = SimplePermissionsNative.instance.isSupported(
        const ReadContacts(),
      );
      expect(supported, isFalse);
      return;
    }

    if (Platform.isMacOS) {
      for (final id in smokeIds) {
        expect(find.byKey(Key('request-$id')), findsOneWidget);
      }
      return;
    }

    for (final id in smokeIds) {
      await tapByKey(tester, 'request-$id');
      final resultText = tester.widget<Text>(
        find.byKey(Key('request-result-$id')),
      );
      expect(resultText.data, isNotNull);
      expect(resultText.data, isNot(contains('pending')));
    }
  });
}
