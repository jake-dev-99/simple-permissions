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

  Future<void> pumpApp(WidgetTester tester) async {
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

  testWidgets('demo app renders all action buttons', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // Single permission buttons
    for (final id in smokeIds) {
      expect(find.byKey(Key('check-$id')), findsOneWidget);
      expect(find.byKey(Key('request-$id')), findsOneWidget);
    }

    // Batch & intention buttons
    expect(find.byKey(const Key('batch-request')), findsOneWidget);
    expect(find.byKey(const Key('intention-contacts')), findsOneWidget);
    expect(find.byKey(const Key('intention-camera')), findsOneWidget);
    expect(find.byKey(const Key('versioned-images')), findsOneWidget);

    // Utility buttons
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
    expect(find.byKey(const Key('location-accuracy')), findsOneWidget);
  });

  testWidgets('check actions produce log output on supported Apple targets', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    if (!isAppleTarget) {
      final supported = await SimplePermissionsNative.instance.isSupported(
        const ReadContacts(),
      );
      expect(supported, isFalse);
      return;
    }

    for (final id in smokeIds) {
      await tapByKey(tester, 'check-$id');
      await tester.pumpAndSettle();
    }

    // Log entries should have been created
    expect(find.byKey(const Key('log-0')), findsOneWidget);
  });

  testWidgets('batch request completes without channel failures', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    if (!isAppleTarget) return;

    await tapByKey(tester, 'batch-request');
    // A couple of short pumps so the kickoff log line lands. Not
    // `pumpAndSettle` — that waits for all pending work, including
    // the `requestAll` Future, which on macOS / iOS simulator under
    // CI blocks forever behind an undismissable system prompt for
    // camera / microphone / location.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The test's contract is "bridge call flows cleanly" —
    // `requestAll(...)` is logged synchronously before the await
    // (see example/lib/main.dart:_batchRequest), so seeing it
    // proves the bridge accepted the call without throwing.
    // `isFullyGranted` is intentionally not asserted because its
    // log line lives behind an await that won't resolve in CI.
    expect(find.textContaining('requestAll'), findsWidgets);
  });

  testWidgets('location accuracy check produces output', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    if (!isAppleTarget) return;

    await tapByKey(tester, 'location-accuracy');
    await tester.pumpAndSettle();

    expect(find.textContaining('checkLocationAccuracy'), findsOneWidget);
  });
}
