# simple_permissions_android

Android implementation for the `simple_permissions_native` federated plugin.

This package is registered automatically by `simple_permissions_native` and provides:

- Runtime permission check/request flows
- App role handling (SMS, Dialer, Browser, Assistant)
- Android system-setting flows (battery optimization, overlays, exact alarms, install packages, all files)
- API-level-aware permission handling via typed permission identifiers

Most apps should depend on `simple_permissions_native` instead of this package directly.

Repository: https://github.com/simplezen/simple-permissions
