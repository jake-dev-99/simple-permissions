import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';
import 'package:simple_permissions_native/src/permission_observer.dart'
    show createPermissionObserver;

class _FakePlatform extends SimplePermissionsPlatform {
  _FakePlatform() : super();
  final Map<Permission, PermissionGrant> grants = {};
  int checkAllCalls = 0;
  Object? errorToThrow;

  /// Held completers by call index so tests can race refreshes.
  final List<Completer<PermissionResult>> checkAllGates = [];

  @override
  Future<PermissionGrant> check(Permission p) async =>
      grants[p] ?? PermissionGrant.denied;

  @override
  Future<PermissionGrant> request(Permission p) async =>
      grants[p] ?? PermissionGrant.denied;

  @override
  Future<PermissionResult> checkAll(List<Permission> perms) async {
    final idx = checkAllCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    if (idx < checkAllGates.length) {
      return checkAllGates[idx].future;
    }
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

class _FakeLifecycle implements PermissionObserverLifecycle {
  void Function()? _onResumed;
  int attachCount = 0;
  int detachCount = 0;

  @override
  VoidCallback attach(void Function() onResumed) {
    attachCount++;
    _onResumed = onResumed;
    return () {
      detachCount++;
      _onResumed = null;
    };
  }

  void triggerResume() => _onResumed?.call();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlatform platform;
  late _FakeLifecycle lifecycle;

  setUp(() {
    platform = _FakePlatform();
    SimplePermissionsPlatform.instance = platform;
    lifecycle = _FakeLifecycle();
  });

  PermissionObserver buildObserver(List<Permission> perms) {
    return createPermissionObserver(
      platform: platform,
      permissions: perms,
      lifecycle: lifecycle,
    );
  }

  group('PermissionObserver', () {
    test('initial refresh emits current grant state', () async {
      platform.grants[const ReadContacts()] = PermissionGrant.granted;
      final observer = buildObserver(const [ReadContacts()]);
      final first = await observer.stream.first;
      expect(first.permissions[const ReadContacts()], PermissionGrant.granted);
      await observer.dispose();
    });

    test('refresh() picks up state changes', () async {
      platform.grants[const DefaultSmsApp()] = PermissionGrant.denied;
      final observer = buildObserver(const [DefaultSmsApp()]);
      await observer.refresh();
      expect(observer.latest?.permissions[const DefaultSmsApp()],
          PermissionGrant.denied);

      platform.grants[const DefaultSmsApp()] = PermissionGrant.granted;
      final result = await observer.refresh();
      expect(
          result.permissions[const DefaultSmsApp()], PermissionGrant.granted);
      await observer.dispose();
    });

    test('grantFor falls back to denied before first refresh', () {
      final observer = buildObserver(const [ReadContacts()]);
      expect(observer.grantFor(const ReadContacts()), PermissionGrant.denied);
      observer.dispose();
    });

    test('lifecycle resume triggers a refresh', () async {
      platform.grants[const ReadContacts()] = PermissionGrant.denied;
      final observer = buildObserver(const [ReadContacts()]);
      await observer.refresh();
      final baseline = platform.checkAllCalls;

      platform.grants[const ReadContacts()] = PermissionGrant.granted;
      lifecycle.triggerResume();

      await Future<void>.delayed(Duration.zero);
      expect(platform.checkAllCalls, greaterThan(baseline));
      expect(observer.latest?.permissions[const ReadContacts()],
          PermissionGrant.granted);
      await observer.dispose();
    });

    test('concurrent refreshes are coalesced', () async {
      // First checkAll gated on a completer — simulates a slow
      // platform call during which additional refresh calls arrive.
      final gate = Completer<PermissionResult>();
      platform.checkAllGates.add(gate);

      final observer = buildObserver(const [ReadContacts()]);
      // createPermissionObserver already kicks off the initial refresh
      // which is held on the gate. These additional calls should
      // coalesce onto the same future.
      final a = observer.refresh();
      final b = observer.refresh();
      final c = observer.refresh();

      expect(identical(a, b), isTrue,
          reason: 'concurrent refresh returns the in-flight future');
      expect(identical(b, c), isTrue);

      gate.complete(PermissionResult({
        const ReadContacts(): PermissionGrant.granted,
      }));
      await Future.wait<PermissionResult>([a, b, c]);

      expect(platform.checkAllCalls, 1,
          reason: 'only one checkAll for all coalesced refreshes');
      await observer.dispose();
    });

    test("platform errors route through stream.onError, don't escape",
        () async {
      platform.errorToThrow = StateError('platform explode');
      final observer = buildObserver(const [ReadContacts()]);
      final errors = <Object>[];
      observer.stream.listen((_) {}, onError: errors.add);

      // Awaiting refresh must resolve (not throw) — important because
      // the lifecycle path unawaits it.
      await observer.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(errors, isNotEmpty);
      expect(errors.first, isA<StateError>());
      await observer.dispose();
    });

    test('dispose detaches lifecycle and closes stream', () async {
      final observer = buildObserver(const [ReadContacts()]);
      expect(lifecycle.attachCount, 1);
      await observer.dispose();
      expect(lifecycle.detachCount, 1);
      lifecycle.triggerResume(); // no-op after dispose
      await Future<void>.delayed(Duration.zero);
      final after = platform.checkAllCalls;
      await observer.refresh();
      expect(platform.checkAllCalls, after,
          reason: 'refresh after dispose does not re-query');
    });

    test('dispose while a refresh is in flight does not leak an emit',
        () async {
      // Gate the initial refresh fired by createPermissionObserver.
      final gate = Completer<PermissionResult>();
      platform.checkAllGates.add(gate);

      final observer = buildObserver(const [ReadContacts()]);
      final events = <PermissionResult>[];
      final errors = <Object>[];
      observer.stream.listen(events.add, onError: errors.add);

      // Dispose BEFORE the in-flight refresh resolves.
      final disposeFuture = observer.dispose();

      // Now let the refresh complete.
      gate.complete(PermissionResult({
        const ReadContacts(): PermissionGrant.granted,
      }));

      await disposeFuture;
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty,
          reason: 'no events should fire after dispose even if an '
              'in-flight refresh resolves late');
      expect(errors, isEmpty);
      expect(observer.latest, isNull,
          reason: 'latest is not mutated by a post-dispose refresh');
    });

    test('lifecycle resume fired after dispose is a no-op', () async {
      final observer = buildObserver(const [ReadContacts()]);
      await observer.refresh();
      await observer.dispose();
      final before = platform.checkAllCalls;

      lifecycle.triggerResume();
      await Future<void>.delayed(Duration.zero);

      expect(platform.checkAllCalls, before,
          reason: 'the observer must ignore lifecycle events after dispose');
    });

    test('refresh errors that resolve after dispose do not escape', () async {
      platform.errorToThrow = StateError('late explode');
      final observer = buildObserver(const [ReadContacts()]);
      final errors = <Object>[];
      observer.stream.listen((_) {}, onError: errors.add);

      // Dispose immediately — the initial refresh is still in flight.
      await observer.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(errors, isEmpty,
          reason: 'errors from refreshes that complete post-dispose must '
              "not land on a closed controller");
    });
  });
}
