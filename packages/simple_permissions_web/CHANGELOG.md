## 1.8.0

- Coordinated release: aligned all federated packages on 1.8.0 to match
  the `simple_permissions_native` facade. No source changes — version
  consolidation only. Fills in the gap from the previously-unpublished
  versions (1.3 — 1.7) where the facade evolved independently of the
  platform packages.
- All cross-package constraints bumped to `^1.8.0`.

## 1.2.0

- Initial release of web platform implementation.
- Browser Permissions API support for camera, microphone, geolocation, and notifications.
- Request flows via `getUserMedia`, `getCurrentPosition`, and `Notification.requestPermission`.