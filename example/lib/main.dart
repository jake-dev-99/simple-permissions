import 'package:flutter/material.dart';
import 'dart:async';

import 'package:simple_permissions/simple_permissions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SimplePermissions.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, bool>? _permissions;
  bool? _smsRole;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final perms = await SimplePermissions.instance.checkPermissions(
      Intention.texting.permissions,
    );
    final role = await SimplePermissions.instance.isRoleHeld(
      Intention.texting.role!,
    );

    if (!mounted) return;

    setState(() {
      _permissions = perms;
      _smsRole = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Simple Permissions Example'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SMS Role: ${_smsRole ?? "checking..."}'),
              const SizedBox(height: 16),
              const Text('Permissions:'),
              if (_permissions != null)
                ..._permissions!.entries.map((e) => Text(
                      '  ${e.key.split('.').last}: ${e.value}',
                    )),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await SimplePermissions.instance.requestPermissions(
              Intention.texting.permissions,
            );
            await _checkPermissions();
          },
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
