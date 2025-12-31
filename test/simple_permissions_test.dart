import 'package:flutter_test/flutter_test.dart';
import 'package:simple_permissions/simple_permissions.dart';
import 'package:simple_permissions/simple_permissions_platform_interface.dart';
import 'package:simple_permissions/simple_permissions_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSimplePermissionsPlatform
    with MockPlatformInterfaceMixin
    implements SimplePermissionsPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SimplePermissionsPlatform initialPlatform = SimplePermissionsPlatform.instance;

  test('$MethodChannelSimplePermissions is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSimplePermissions>());
  });

  test('getPlatformVersion', () async {
    SimplePermissions simplePermissionsPlugin = SimplePermissions();
    MockSimplePermissionsPlatform fakePlatform = MockSimplePermissionsPlatform();
    SimplePermissionsPlatform.instance = fakePlatform;

    expect(await simplePermissionsPlugin.getPlatformVersion(), '42');
  });
}
