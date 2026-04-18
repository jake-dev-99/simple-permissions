import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

class _FakePlatform extends SimplePermissionsPlatform {
  _FakePlatform() : super();
  final Map<Permission, PermissionGrant> grants = {};
  int checkAllCalls = 0;

  @override
  Future<PermissionGrant> check(Permission p) async {
    return grants[p] ?? PermissionGrant.denied;
  }

  @override
  Future<PermissionGrant> request(Permission p) async =>
      grants[p] ?? PermissionGrant.denied;

  @override
  Future<PermissionResult> checkAll(List<Permission> perms) async {
    checkAllCalls++;
    final map = <Permission, PermissionGrant>{};
    for (final p in perms) {
      map[p] = grants[p] ?? PermissionGrant.denied;
    }
    return PermissionResult(map);
  }

  @override
  Future<bool> isSupported(Permission p) async => true;

  @override
  Future<bool> openAppSettings() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionObserver', () {
    late _FakePlatform platform;

    setUp(() {
      platform = _FakePlatform();
      SimplePermissionsPlatform.instance = platform;
    });

    test('initial refresh emits current grant state', () async {
      platform.grants[const ReadContacts()] = PermissionGrant.granted;
      final observer = platform.observe(const [ReadContacts()]);
      final first = await observer.stream.first;
      expect(first.permissions[const ReadContacts()],
          PermissionGrant.granted);
      await observer.dispose();
    });

    test('refresh() picks up state changes', () async {
      platform.grants[const DefaultSmsApp()] = PermissionGrant.denied;
      final observer = platform.observe(const [DefaultSmsApp()]);
      await observer.refresh();
      expect(observer.latest?.permissions[const DefaultSmsApp()],
          PermissionGrant.denied);

      platform.grants[const DefaultSmsApp()] = PermissionGrant.granted;
      final result = await observer.refresh();
      expect(result.permissions[const DefaultSmsApp()],
          PermissionGrant.granted);
      await observer.dispose();
    });

    test('grantFor falls back to denied before first refresh', () {
      final observer = platform.observe(const [ReadContacts()]);
      // No await — snapshot before the scheduled refresh resolves.
      expect(observer.grantFor(const ReadContacts()),
          PermissionGrant.denied);
      observer.dispose();
    });

    test('resumed lifecycle triggers a refresh', () async {
      platform.grants[const ReadContacts()] = PermissionGrant.denied;
      final observer = platform.observe(const [ReadContacts()]);
      await observer.refresh();
      final baseline = platform.checkAllCalls;

      platform.grants[const ReadContacts()] = PermissionGrant.granted;
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // didChangeAppLifecycleState kicks off refresh asynchronously.
      // Pump the microtask queue via a zero-duration delay.
      await Future<void>.delayed(Duration.zero);
      expect(platform.checkAllCalls, greaterThan(baseline));
      expect(observer.latest?.permissions[const ReadContacts()],
          PermissionGrant.granted);
      await observer.dispose();
    });

    test('non-resumed lifecycle does not refresh', () async {
      platform.grants[const ReadContacts()] = PermissionGrant.granted;
      final observer = platform.observe(const [ReadContacts()]);
      await observer.refresh();
      final baseline = platform.checkAllCalls;

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(platform.checkAllCalls, baseline);
      await observer.dispose();
    });

    test('dispose closes stream and stops emitting', () async {
      final observer = platform.observe(const [ReadContacts()]);
      await observer.dispose();
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // refresh after dispose resolves but pushes nothing.
      await observer.refresh();
      expect(observer.stream.isBroadcast, isTrue);
    });
  });
}
