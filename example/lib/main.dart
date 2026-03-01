import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SimplePermissionsNative.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  PermissionResult? _result;
  bool? _textingReady;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final result = await SimplePermissionsNative.instance
        .checkIntentionDetailed(Intention.texting);
    final ready = await SimplePermissionsNative.instance.checkIntention(
      Intention.texting,
    );

    if (!mounted) return;

    setState(() {
      _result = result;
      _textingReady = ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Simple Permissions Example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Texting Ready: ${_textingReady ?? "checking..."}'),
              const SizedBox(height: 16),
              const Text(
                'Permissions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_result != null)
                ..._result!.permissions.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text('${e.key.identifier}: ${e.value.name}'),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final grant = await SimplePermissionsNative.instance.check(
                    const ReadContacts(),
                  );
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Contacts: ${grant.name}')),
                  );
                },
                child: const Text('Check Contacts'),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await SimplePermissionsNative.instance
                .requestIntentionDetailed(Intention.texting);
            if (!mounted) return;
            if (result.requiresSettings) {
              await SimplePermissionsNative.instance.openAppSettings();
            }
            await _checkPermissions();
          },
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
