#!/usr/bin/env bash
set -euo pipefail

# Publish order matters: platform_interface first (no internal deps),
# then platform implementations (depend only on interface),
# then the root app-facing package (depends on all).

PACKAGES=(
  packages/simple_permissions_platform_interface
  packages/simple_permissions_android
  packages/simple_permissions_ios
  packages/simple_permissions_macos
  packages/simple_permissions_web
  .
)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=true

for arg in "$@"; do
  case "$arg" in
    --live) DRY_RUN=false ;;
    --help|-h)
      echo "Usage: tool/publish.sh [--live]"
      echo ""
      echo "  --live    Actually publish (default is dry-run)"
      echo ""
      echo "Publish order:"
      for pkg in "${PACKAGES[@]}"; do
        name=$(grep '^name:' "$ROOT/$pkg/pubspec.yaml" | head -1 | awk '{print $2}')
        version=$(grep '^version:' "$ROOT/$pkg/pubspec.yaml" | head -1 | awk '{print $2}')
        echo "  $name $version"
      done
      exit 0
      ;;
  esac
done

if $DRY_RUN; then
  echo "=== DRY RUN (pass --live to publish for real) ==="
  echo ""
fi

failed=()

for pkg in "${PACKAGES[@]}"; do
  dir="$ROOT/$pkg"
  name=$(grep '^name:' "$dir/pubspec.yaml" | head -1 | awk '{print $2}')
  version=$(grep '^version:' "$dir/pubspec.yaml" | head -1 | awk '{print $2}')

  echo "──────────────────────────────────────────"
  echo "📦 $name $version"
  echo "   $dir"
  echo ""

  cd "$dir"

  # Resolve deps
  flutter pub get --no-example > /dev/null 2>&1 || flutter pub get > /dev/null 2>&1

  if $DRY_RUN; then
    flutter pub publish --dry-run 2>&1 | tail -20
    echo ""
  else
    # --force skips the interactive y/N prompt
    if flutter pub publish --force 2>&1; then
      echo "✅ $name $version published"
    else
      echo "❌ $name $version FAILED"
      failed+=("$name")
    fi
    echo ""

    # Brief pause between publishes to let pub.dev index
    if [ "$pkg" != "." ]; then
      echo "   Waiting 15s for pub.dev to index..."
      sleep 15
    fi
  fi
done

echo "══════════════════════════════════════════"
if [ ${#failed[@]} -eq 0 ]; then
  if $DRY_RUN; then
    echo "Dry run complete. Run with --live to publish."
  else
    echo "✅ All packages published successfully."
  fi
else
  echo "❌ Failed packages: ${failed[*]}"
  exit 1
fi
