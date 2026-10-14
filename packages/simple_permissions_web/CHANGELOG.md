## 1.3.4

- fix(UNFY-123): keep Flutter analyzer migration source clean
- chore(release): cut 6 tags (patch bump)
- chore(release): cut 6 tags (patch bump)
- chore(release): reset versions to align with pub.dev
- chore(release): align federated packages on coordinated 1.8.0
- docs(web): document observer refresh cadence on web
- refactor(web): log swallowed browser API errors in debug mode
- refactor(web): extract browser permission state strings to constants
- chore(lints): elevate silent-bug lints to errors across packages
- fix(web): harden geolocation request against double-settle
- Require simple_permissions_platform_interface ^1.3.4.

## 1.3.3

- (no commits in packages/simple_permissions_web since simple_permissions_web-v1.3.2)
## 1.3.2

- (no commits in packages/simple_permissions_web since simple_permissions_web-v1.3.1)
## 1.3.1

### Reset to align with pub.dev's published series

This package on pub.dev is at 1.3.0. Local git tags 1.8.0,
1.8.1 (and 1.3.1 on `_android`) were authored ahead of the next
publish but never reached pub.dev. Orphan tags deleted from
origin and the version reset to the smallest patch above the
last-published version (1.3.0 → 1.3.1).

Cross-package constraint on `simple_permissions_platform_interface`
lowered from `^1.8.0` to `^1.3.0` to match the published series.

The 1.8.0 work described below is not lost — it lives in source
and will surface in published form through subsequent bumps.
Entry kept for archival reference.

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