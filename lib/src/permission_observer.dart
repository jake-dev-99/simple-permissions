import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

/// Abstract lifecycle source. [PermissionObserver] defaults to
/// driving itself off [WidgetsBinding], but tests and alternate
/// embeddings can provide any implementation — the observer only
/// needs to know when the app resumed.
abstract class PermissionObserverLifecycle {
  /// Register [onResumed]; return a disposer that detaches it.
  VoidCallback attach(void Function() onResumed);
}

/// Default lifecycle source — hooks [WidgetsBinding] so observers
/// refresh whenever the app returns to foreground.
class WidgetsBindingLifecycle implements PermissionObserverLifecycle {
  WidgetsBindingLifecycle({WidgetsBinding? binding})
      : _binding = binding ?? WidgetsBinding.instance;

  final WidgetsBinding _binding;

  @override
  VoidCallback attach(void Function() onResumed) {
    final adapter = _Adapter(onResumed);
    _binding.addObserver(adapter);
    return () => _binding.removeObserver(adapter);
  }
}

class _Adapter extends WidgetsBindingObserver {
  _Adapter(this._onResumed);
  final void Function() _onResumed;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }
}

/// Reactive view of the grant state for a set of [Permission]s.
///
/// Permission + role state changes outside the app (user flips a
/// switch in system Settings, grants the default-SMS role via the
/// system dialog, a background handler loses access) don't generate
/// events — there's no platform-level hook for "permission changed".
/// The accepted pattern is to re-query when the app regains
/// foreground, and after every explicit request returns.
///
/// Lives in the native facade package (not the platform interface)
/// so the platform interface stays Flutter-free. Lifecycle wiring
/// is pluggable via [PermissionObserverLifecycle] to keep the class
/// testable and let alternate embeddings drive it from their own
/// event loops.
///
/// Create via [SimplePermissionsNative.instance.observe]; dispose
/// when done to detach the lifecycle listener and close the stream.
class PermissionObserver {
  PermissionObserver._({
    required this.permissions,
    required SimplePermissionsPlatform platform,
    PermissionObserverLifecycle? lifecycle,
  }) : _platform = platform {
    final source = lifecycle ?? WidgetsBindingLifecycle();
    _detach = source.attach(_onResumed);
  }

  /// The permissions (and roles, since [AppRole] extends [Permission])
  /// being observed. Immutable for the observer's lifetime — to watch
  /// a different set, dispose and create a new one.
  final List<Permission> permissions;

  final SimplePermissionsPlatform _platform;
  late final VoidCallback _detach;

  final StreamController<PermissionResult> _controller =
      StreamController<PermissionResult>.broadcast();
  PermissionResult? _latest;
  Future<PermissionResult>? _inFlight;
  bool _disposed = false;

  /// Broadcast stream of grant results. Emits after every successful
  /// [refresh], including the implicit refresh fired on app resume
  /// and the initial refresh kicked off by the constructor.
  /// Platform errors surface as stream errors — listen via
  /// [Stream.listen]'s `onError` to react.
  Stream<PermissionResult> get stream => _controller.stream;

  /// Most recent result, or null before the first successful refresh.
  PermissionResult? get latest => _latest;

  /// Convenience: the grant for a single observed [permission]. Falls
  /// back to [PermissionGrant.denied] if the observer hasn't
  /// refreshed yet or [permission] isn't in [permissions].
  PermissionGrant grantFor(Permission permission) {
    final map = _latest?.permissions;
    if (map == null) return PermissionGrant.denied;
    return map[permission] ?? PermissionGrant.denied;
  }

  /// Re-query the platform and push the result onto [stream].
  ///
  /// Concurrent calls are coalesced: if a refresh is already in
  /// flight, subsequent callers receive that same future. Avoids
  /// redundant platform work and keeps result ordering predictable
  /// (e.g. when a manual refresh races with the lifecycle-driven
  /// resume refresh).
  ///
  /// Platform failures are caught and routed onto the stream as
  /// errors rather than escaping as uncaught exceptions — important
  /// because the resume path fires this unawaited. The returned
  /// future resolves with the last known [latest] (or an empty
  /// [PermissionResult] if never populated) on error so awaited
  /// callers see a usable value; listen to the stream for error
  /// observability.
  Future<PermissionResult> refresh() {
    if (_disposed) {
      return Future<PermissionResult>.value(
          _latest ?? PermissionResult(const {}));
    }
    final pending = _inFlight;
    if (pending != null) return pending;

    final future = _runRefresh();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<PermissionResult> _runRefresh() async {
    try {
      final result = await _platform.checkAll(permissions);
      if (!_disposed) {
        _latest = result;
        if (!_controller.isClosed) _controller.add(result);
      }
      return result;
    } catch (err, stack) {
      if (!_disposed && !_controller.isClosed) {
        _controller.addError(err, stack);
      }
      return _latest ?? PermissionResult(const {});
    }
  }

  void _onResumed() {
    if (_disposed) return;
    // Fire-and-forget — errors route through the stream via refresh's
    // try/catch, so no uncaught exceptions escape here.
    // ignore: unawaited_futures, discarded_futures
    refresh();
  }

  /// Detach the lifecycle listener and close the stream. After
  /// [dispose], further [refresh] calls resolve but emit nothing.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _detach();
    await _controller.close();
  }
}

/// Internal constructor bridge — keeps [PermissionObserver]'s `_`
/// ctor private while letting the facade + tests instantiate it.
/// Does an initial unawaited refresh so subscribers see a value
/// quickly; errors propagate via the stream.
PermissionObserver createPermissionObserver({
  required SimplePermissionsPlatform platform,
  required List<Permission> permissions,
  PermissionObserverLifecycle? lifecycle,
}) {
  final observer = PermissionObserver._(
    permissions: List.unmodifiable(permissions),
    platform: platform,
    lifecycle: lifecycle,
  );
  // ignore: unawaited_futures, discarded_futures
  observer.refresh();
  return observer;
}
