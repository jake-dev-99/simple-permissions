# Release flow

Releases use `main`, a manual **Cut Release** dispatch, and tag-triggered
pub.dev publication. A merge does not publish a package.

## Cutting a release

1. Land the reviewed change through a PR to `main`.
2. Dispatch [release.yml](../.github/workflows/release.yml) on `main`, choosing
   the package and `patch`, `minor`, or `major` increment.
3. The cut validates an isolated package copy against published dependencies,
   without development overrides. Resolution and analysis must pass before
   the workflow updates its pubspec and CHANGELOG, commits, and tags.
4. Each tag triggers [deploy.yml](../.github/workflows/deploy.yml). It verifies
   ancestry and version, configures temporary pub.dev OIDC credentials, and
   runs `flutter pub publish --force` with normal package validation.

The increment applies to the current source version, including versions already
changed in a PR. `dry_run=true` validates and reports the candidate without
pushing a commit or tag. Do not use `all` when selected packages depend on
versions that have not been published yet.

## MMS dependency release order (UNFY-123)

Published Android, iOS, macOS, and Web `1.3.0` packages require an unpublished
interface `^1.8.0`. The latest published interface is `1.3.0`. Older facade
constraints therefore resolve platform `1.2.0` packages; Android `1.2.0` lacks
the native `PermissionGuards` API required by simple-sms.
Current platform sources use the compatible interface `^1.3.0`.
No platform-interface contract change is required for this repair.

Release in this order, verifying every platform publication before the facade:

1. `simple_permissions_android`, `simple_permissions_ios`,
   `simple_permissions_macos`, and `simple_permissions_web`: each patches its
   source `1.3.3` to `1.3.4`.
2. `simple_permissions_native`: patch from source `1.6.3` to `1.6.4`. Each
   platform minimum is `^1.3.4`, preventing resolution of incompatible packages.
3. Raise simple-sms's facade minimum to `^1.6.4`, then validate and build the
   SMS root and example with published dependencies and no overrides.

Local sibling builds establish source compatibility. They do not establish
published compatibility. Every platform must validate against published
interface `1.3.0` before release; the facade cut waits for all four publications.

## Package tags

| Package | Tag prefix | Directory |
| --- | --- | --- |
| `simple_permissions_native` | `simple_permissions_native-v` | `.` |
| `simple_permissions_platform_interface` | `simple_permissions_platform_interface-v` | `packages/simple_permissions_platform_interface` |
| `simple_permissions_android` | `simple_permissions_android-v` | `packages/simple_permissions_android` |
| `simple_permissions_ios` | `simple_permissions_ios-v` | `packages/simple_permissions_ios` |
| `simple_permissions_macos` | `simple_permissions_macos-v` | `packages/simple_permissions_macos` |
| `simple_permissions_web` | `simple_permissions_web-v` | `packages/simple_permissions_web` |

Versions advance independently. A breaking platform-interface change requires
coordinated major versions and implementations across the federation.

## Publication setup and retries

The cut uses `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` to push release
commits and tags. The release app must have the repository ruleset bypass
required by that workflow. Do not substitute direct pushes or retarget tags.

Each package's pub.dev Admin page must enable automated publication for
`jake-dev-99/simple-permissions`, with tag pattern `<package>-v{{version}}`.
The workflow uses OIDC, with no stored pub.dev credentials.

For a failed publication, retain the existing version and tag. Dispatch Deploy
on that tag ref with the same tag input, for example:

```sh
gh workflow run deploy.yml --ref simple_permissions_android-v1.3.4 \
  -f tag=simple_permissions_android-v1.3.4
```

Confirm pub.dev's version record before retrying an ambiguous publication.
