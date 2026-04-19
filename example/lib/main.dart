import 'package:flutter/material.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SimplePermissionsNative.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const PermissionsDemo(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      ),
    );
  }
}

// =============================================================================
// Demo page
// =============================================================================

class PermissionsDemo extends StatefulWidget {
  const PermissionsDemo({super.key});

  @override
  State<PermissionsDemo> createState() => _PermissionsDemoState();
}

class _PermissionsDemoState extends State<PermissionsDemo> {
  final _perms = SimplePermissionsNative.instance;
  final _log = <String>[];

  void _addLog(String message) {
    setState(() => _log.insert(0, message));
  }

  // ---------------------------------------------------------------------------
  // Single permission check/request
  // ---------------------------------------------------------------------------

  static const _singlePermissions = <(String, Permission)>[
    ('Contacts', ReadContacts()),
    ('Camera', CameraAccess()),
    ('Microphone', RecordAudio()),
    ('Location', FineLocation()),
  ];

  Future<void> _checkSingle(Permission permission, String label) async {
    final grant = await _perms.check(permission);
    _addLog('check($label) = ${grant.name}');
  }

  Future<void> _requestSingle(Permission permission, String label) async {
    final grant = await _perms.request(permission);
    _addLog('request($label) = ${grant.name}');

    if (grant == PermissionGrant.permanentlyDenied) {
      _addLog('  -> permanentlyDenied: call openAppSettings()');
    }
  }

  // ---------------------------------------------------------------------------
  // Batch request
  // ---------------------------------------------------------------------------

  Future<void> _batchRequest() async {
    // Log the call kickoff BEFORE the await. On macOS/iOS simulator
    // under CI the system prompt can't be dismissed, so the await
    // blocks indefinitely and no result-dependent log line ever
    // fires — which used to make the integration smoke test fail
    // even though the bridge call itself was healthy. Emitting the
    // header first lets tests verify the call reached the bridge
    // without gating on grant outcome.
    _addLog('requestAll(camera, mic, location):');
    final result = await _perms.requestAll(const [
      CameraAccess(),
      RecordAudio(),
      FineLocation(),
    ]);

    _addLog('  isFullyGranted = ${result.isFullyGranted}');

    if (result.hasDenial) {
      _addLog(
        '  denied = ${result.denied.map((p) => p.identifier).join(', ')}',
      );
    }
    if (result.requiresSettings) {
      _addLog(
        '  permanentlyDenied = ${result.permanentlyDenied.map((p) => p.identifier).join(', ')}',
      );
    }
    if (result.hasUnsupported) {
      _addLog(
        '  unsupported = ${result.unsupported.map((p) => p.identifier).join(', ')}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Intention-based request
  // ---------------------------------------------------------------------------

  Future<void> _requestIntention(Intention intention) async {
    final result = await _perms.requestIntentionDetailed(intention);
    _addLog('requestIntention(${intention.name}):');
    _addLog('  isFullyGranted = ${result.isFullyGranted}');

    for (final entry in result.permissions.entries) {
      _addLog('  ${entry.key.identifier} = ${entry.value.name}');
    }
  }

  // ---------------------------------------------------------------------------
  // Versioned permission
  // ---------------------------------------------------------------------------

  Future<void> _requestVersioned() async {
    final permission = VersionedPermission.images();
    final grant = await _perms.request(permission);
    _addLog('request(VersionedPermission.images()) = ${grant.name}');
    _addLog('  resolved identifier = ${permission.identifier}');
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  Future<void> _openSettings() async {
    final opened = await _perms.openAppSettings();
    _addLog('openAppSettings() = $opened');
  }

  Future<void> _checkLocationAccuracy() async {
    final accuracy = await _perms.checkLocationAccuracy();
    _addLog('checkLocationAccuracy() = ${accuracy.name}');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Permissions Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _log.clear()),
            tooltip: 'Clear log',
          ),
        ],
      ),
      body: Column(
        children: [
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Single permissions
                Text(
                  'Single permissions',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, permission) in _singlePermissions) ...[
                      FilledButton.tonal(
                        key: Key('check-${permission.identifier}'),
                        onPressed: () => _checkSingle(permission, label),
                        child: Text('Check $label'),
                      ),
                      OutlinedButton(
                        key: Key('request-${permission.identifier}'),
                        onPressed: () => _requestSingle(permission, label),
                        child: Text('Request $label'),
                      ),
                    ],
                  ],
                ),

                const Divider(height: 24),

                // Batch & Intentions
                Text(
                  'Batch & Intentions',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('batch-request'),
                      onPressed: _batchRequest,
                      child: const Text('Batch Request'),
                    ),
                    FilledButton(
                      key: const Key('intention-contacts'),
                      onPressed: () => _requestIntention(Intention.contacts),
                      child: const Text('Intention: Contacts'),
                    ),
                    FilledButton(
                      key: const Key('intention-camera'),
                      onPressed: () => _requestIntention(Intention.camera),
                      child: const Text('Intention: Camera'),
                    ),
                    OutlinedButton(
                      key: const Key('versioned-images'),
                      onPressed: _requestVersioned,
                      child: const Text('Versioned Images'),
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Utilities
                Text(
                  'Utilities',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('open-settings'),
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Settings'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('location-accuracy'),
                      onPressed: _checkLocationAccuracy,
                      icon: const Icon(Icons.gps_fixed),
                      label: const Text('Location Accuracy'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Log output
          Expanded(
            child:
                _log.isEmpty
                    ? const Center(
                      child: Text(
                        'Tap a button above to see results',
                        key: Key('empty-log'),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _log.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _log[index],
                          key: Key('log-$index'),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
