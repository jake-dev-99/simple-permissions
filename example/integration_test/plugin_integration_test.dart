import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:simple_permissions/simple_permissions.dart';

const int _androidApiLevel = int.fromEnvironment(
  'ANDROID_API_LEVEL',
  defaultValue: 0,
);

bool _runForApiLevel(int level) => _androidApiLevel == level;
bool _runForApiLevelAtLeast(int level) =>
    _androidApiLevel >= level && _androidApiLevel != 0;

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

  group('Android API matrix', () {
    testWidgets(
      'API 31 baseline: modern media + notifications are treated as not required',
      (WidgetTester tester) async {
        await SimplePermissions.initialize();
        final result = await SimplePermissions.instance.checkPermissions([
          'android.permission.READ_EXTERNAL_STORAGE',
          'android.permission.READ_MEDIA_IMAGES',
          'android.permission.READ_MEDIA_VIDEO',
          'android.permission.READ_MEDIA_AUDIO',
          'android.permission.POST_NOTIFICATIONS',
        ]);

        // On API 31 these permissions are not runtime-applicable and should
        // normalize to granted=true.
        expect(result['android.permission.READ_MEDIA_IMAGES'], isTrue);
        expect(result['android.permission.READ_MEDIA_VIDEO'], isTrue);
        expect(result['android.permission.READ_MEDIA_AUDIO'], isTrue);
        expect(result['android.permission.POST_NOTIFICATIONS'], isTrue);
      },
      skip: !_runForApiLevel(31),
    );

    testWidgets(
      'API 33 behavior: deprecated external storage permission is not required',
      (WidgetTester tester) async {
        await SimplePermissions.initialize();
        final result = await SimplePermissions.instance.checkPermissions(
          Intention.fileAccess.permissions,
        );

        // On API 33+, READ_EXTERNAL_STORAGE is deprecated and normalized.
        expect(result['android.permission.READ_EXTERNAL_STORAGE'], isTrue);
        // Media permissions remain real runtime permissions on API 33+.
        expect(
          result.containsKey('android.permission.READ_MEDIA_IMAGES'),
          isTrue,
        );
        expect(
          result.containsKey('android.permission.READ_MEDIA_VIDEO'),
          isTrue,
        );
        expect(
          result.containsKey('android.permission.READ_MEDIA_AUDIO'),
          isTrue,
        );
      },
      skip: !_runForApiLevel(33),
    );

    testWidgets(
      'API 34+ behavior: file/media checks remain stable and deterministic',
      (WidgetTester tester) async {
        await SimplePermissions.initialize();
        final detailed = await SimplePermissions.instance.checkDetailed(
          Intention.fileAccess,
        );

        expect(
          detailed.permissions.keys,
          contains('android.permission.READ_EXTERNAL_STORAGE'),
        );
        expect(
          detailed.permissions.keys,
          contains('android.permission.READ_MEDIA_IMAGES'),
        );
        expect(
          detailed.permissions['android.permission.READ_EXTERNAL_STORAGE'],
          PermissionStatus.granted,
        );
      },
      skip: !_runForApiLevelAtLeast(34),
    );
  });
}
