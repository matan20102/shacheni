#!/usr/bin/env bash
# Netlify build: install Flutter (pinned to the version used in development), then build the web
# app with the Supabase settings from Netlify environment variables. Run from the repo root.
set -euo pipefail

FLUTTER_VERSION="3.47.7"
FLUTTER_DIR="${NETLIFY_CACHE_DIR:-$HOME/.cache}/flutter-$FLUTTER_VERSION"

: "${SUPABASE_URL:?Set SUPABASE_URL in Netlify → Site configuration → Environment variables}"
: "${SUPABASE_PUBLISHABLE_KEY:?Set SUPABASE_PUBLISHABLE_KEY in Netlify → Site configuration → Environment variables}"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION"
  rm -rf "$FLUTTER_DIR"
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --disable-analytics >/dev/null 2>&1 || true
flutter --version

cd app
mkdir -p config
cat > config/netlify.json <<EOF
{
  "SUPABASE_URL": "$SUPABASE_URL",
  "SUPABASE_PUBLISHABLE_KEY": "$SUPABASE_PUBLISHABLE_KEY"
}
EOF
flutter pub get
flutter build web --release --dart-define-from-file=config/netlify.json
