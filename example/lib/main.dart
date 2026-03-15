import 'package:flutter/material.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SimplePermissionsNative.initialize();
  runApp(const MyApp());
}

class SmokePermissionCase {
  const SmokePermissionCase({required this.label, required this.permission});

  final String label;
  final Permission permission;

  String get identifier => permission.identifier;
}

const smokePermissions = <SmokePermissionCase>[
  SmokePermissionCase(label: 'Contacts', permission: ReadContacts()),
  SmokePermissionCase(label: 'Camera', permission: CameraAccess()),
  SmokePermissionCase(label: 'Microphone', permission: RecordAudio()),
  SmokePermissionCase(label: 'Location', permission: FineLocation()),
];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SmokeHarnessPage(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      ),
    );
  }
}

class SmokeHarnessPage extends StatefulWidget {
  const SmokeHarnessPage({super.key});

  @override
  State<SmokeHarnessPage> createState() => _SmokeHarnessPageState();
}

class _SmokeHarnessPageState extends State<SmokeHarnessPage> {
  final Map<String, bool> _supported = {};
  final Map<String, PermissionGrant?> _lastCheck = {};
  final Map<String, PermissionGrant?> _lastRequest = {};
  LocationAccuracyStatus? _locationAccuracy;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _primeSupportState();
  }

  Future<void> _primeSupportState() async {
    final support = <String, bool>{
      for (final item in smokePermissions)
        item.identifier: SimplePermissionsNative.instance.isSupported(
          item.permission,
        ),
    };
    final locationAccuracy =
        await SimplePermissionsNative.instance.checkLocationAccuracy();
    if (!mounted) return;
    setState(() {
      _supported
        ..clear()
        ..addAll(support);
      _locationAccuracy = locationAccuracy;
    });
  }

  Future<void> _checkPermission(SmokePermissionCase item) async {
    setState(() {
      _busy = true;
    });
    final grant = await SimplePermissionsNative.instance.check(item.permission);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastCheck[item.identifier] = grant;
    });
  }

  Future<void> _requestPermission(SmokePermissionCase item) async {
    setState(() {
      _busy = true;
    });
    final grant = await SimplePermissionsNative.instance.request(
      item.permission,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastRequest[item.identifier] = grant;
    });
  }

  String _grantLabel(PermissionGrant? grant) => grant?.name ?? 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Permissions Smoke Harness')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Initialized: ${SimplePermissionsNative.isInitialized}',
              key: const Key('initialized-status'),
            ),
            Text(
              'Location accuracy: ${_locationAccuracy?.name ?? "loading"}',
              key: const Key('location-accuracy-status'),
            ),
            const SizedBox(height: 16),
            for (final item in smokePermissions)
              _PermissionTile(
                item: item,
                busy: _busy,
                supported: _supported[item.identifier] ?? false,
                lastCheck: _lastCheck[item.identifier],
                lastRequest: _lastRequest[item.identifier],
                onCheck: () => _checkPermission(item),
                onRequest: () => _requestPermission(item),
                grantLabel: _grantLabel,
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.item,
    required this.busy,
    required this.supported,
    required this.lastCheck,
    required this.lastRequest,
    required this.onCheck,
    required this.onRequest,
    required this.grantLabel,
  });

  final SmokePermissionCase item;
  final bool busy;
  final bool supported;
  final PermissionGrant? lastCheck;
  final PermissionGrant? lastRequest;
  final VoidCallback onCheck;
  final VoidCallback onRequest;
  final String Function(PermissionGrant? grant) grantLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('permission-card-${item.identifier}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.label, style: Theme.of(context).textTheme.titleMedium),
            Text(item.identifier),
            const SizedBox(height: 8),
            Text(
              'supported=$supported',
              key: Key('supported-${item.identifier}'),
            ),
            Text(
              'check=${grantLabel(lastCheck)}',
              key: Key('check-result-${item.identifier}'),
            ),
            Text(
              'request=${grantLabel(lastRequest)}',
              key: Key('request-result-${item.identifier}'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: Key('check-${item.identifier}'),
                  onPressed: busy ? null : onCheck,
                  child: const Text('Check'),
                ),
                OutlinedButton(
                  key: Key('request-${item.identifier}'),
                  onPressed: busy ? null : onRequest,
                  child: const Text('Request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
