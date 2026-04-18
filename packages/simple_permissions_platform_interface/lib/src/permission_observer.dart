import 'dart:async';

import 'package:flutter/widgets.dart';

import 'permission_grant.dart';
import 'permission_result.dart';
import 'permissions/permission.dart';
import 'simple_permissions_platform.dart';

/// Reactive view of the grant state for a set of [Permission]s.
///
/// Permission + role state changes outside the app (user flips a
/// switch in system Settings, grants the default-SMS role via the
/// system dialog, a background handler loses access) don't generate
/// events — there's no platform-level hook for "permission changed".
/// The accepted pattern is to re-query when the app regains
/// foreground, and after every explicit request returns.
///
/// [PermissionObserver] does exactly that:
///   - Subscribes to [WidgetsBinding]'s lifecycle observer.
///   - Refreshes the cached [PermissionResult] on
///     [AppLifecycleState.resumed].
///   - [refresh] is callable directly after any flow the caller
///     knows could change state (e.g. after awaiting a
///     [SimplePermissionsPlatform.request]).
///
/// Consumers listen to [stream] to drive reactive UI (disable
/// buttons, show "grant to continue" banners, light up full
/// functionality once role is held).
///
/// Create via [SimplePermissionsPlatform.observe]; dispose when done
/// to detach the lifecycle observer and close the stream.
class PermissionObserver with WidgetsBindingObserver {
  PermissionObserver._({
    required this.permissions,
    required SimplePermissionsPlatform platform,
    WidgetsBinding? binding,
  })  : _platform = platform,
        _binding = binding ?? WidgetsBinding.instance {
    _binding.addObserver(this);
  }

  /// The permissions (and roles, since [AppRole] extends [Permission])
  /// being observed. Immutable for the observer's lifetime — to watch
  /// a different set, dispose and create a new one.
  final List<Permission> permissions;

  final SimplePermissionsPlatform _platform;
  final WidgetsBinding _binding;

  final StreamController<PermissionResult> _controller =
      StreamController<PermissionResult>.broadcast();
  PermissionResult? _latest;
  bool _disposed = false;

  /// Broadcast stream of grant results. Emits after every [refresh],
  /// including the implicit refresh fired on app resume and the
  /// initial refresh kicked off by the constructor.
  Stream<PermissionResult> get stream => _controller.stream;

  /// Most recent result, or null before the first refresh completes.
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
  /// Returns the fresh [PermissionResult] (also available via
  /// [latest] after the future completes). Safe to call from any
  /// async context; the controller guards against emits after
  /// [dispose].
  Future<PermissionResult> refresh() async {
    final result = await _platform.checkAll(permissions);
    if (_disposed) return result;
    _latest = result;
    if (!_controller.isClosed) _controller.add(result);
    return result;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state != AppLifecycleState.resumed) return;
    // Fire-and-forget; errors surface via the stream if any. Lifecycle
    // callbacks are sync so we can't await here anyway.
    // ignore: unawaited_futures, discarded_futures
    refresh();
  }

  /// Detach the lifecycle observer and close the stream. After
  /// [dispose], further [refresh] calls resolve but emit nothing.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _binding.removeObserver(this);
    await _controller.close();
  }
}

/// Internal constructor bridge — keeps [PermissionObserver]'s `_`
/// ctor private while letting [SimplePermissionsPlatform.observe]
/// and tests instantiate it.
PermissionObserver createPermissionObserverForPlatform({
  required SimplePermissionsPlatform platform,
  required List<Permission> permissions,
  WidgetsBinding? binding,
}) {
  final observer = PermissionObserver._(
    permissions: List.unmodifiable(permissions),
    platform: platform,
    binding: binding,
  );
  // Kick off an initial refresh so subscribers get a value quickly.
  // Errors propagate via the stream; callers await if they need the
  // first result synchronously.
  // ignore: unawaited_futures, discarded_futures
  observer.refresh();
  return observer;
}
