# simple_permissions_platform_interface

Platform interface for the `simple_permissions_native` federated plugin.

This package defines the shared API contracts and data types used by all platform implementations:

- `Permission` sealed class hierarchy
- `PermissionGrant`
- `PermissionResult`
- `Intention`
- `SimplePermissionsPlatform`
- `LocationAccuracyStatus`

Consumers should typically depend on `simple_permissions_native` instead of this package directly.

Repository: https://github.com/simplezen/simple-permissions
