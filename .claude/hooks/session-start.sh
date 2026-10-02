#!/bin/bash
# Installs the Flutter SDK that CI uses (release.yaml) so analyze and tests work
# in Claude Code cloud sessions. Idempotent: skips the download when the right
# version is already installed.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Single source of truth for the Flutter version: the CI target in release.yaml.
FLUTTER_VERSION="$(sed -n "s/^[[:space:]]*flutter:[[:space:]]*'\{0,1\}\([0-9][0-9.]*\)'\{0,1\}.*/\1/p" release.yaml | head -1)"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.38.4}"
FLUTTER_ROOT="${FLUTTER_SDK_HOME:-$HOME/.flutter-sdk}/$FLUTTER_VERSION/flutter"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION into $FLUTTER_ROOT" >&2
  mkdir -p "$(dirname "$FLUTTER_ROOT")"
  archive="$(mktemp -d)/flutter.tar.xz"
  curl -fsSL --retry 4 --retry-delay 2 -o "$archive" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar -xf "$archive" -C "$(dirname "$FLUTTER_ROOT")"
  rm -f "$archive"
fi

git config --global --add safe.directory "$FLUTTER_ROOT" || true
export PATH="$FLUTTER_ROOT/bin:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_ROOT/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

flutter --disable-analytics >/dev/null 2>&1 || true
flutter --version >&2
flutter pub get >&2
flutter gen-l10n >&2
