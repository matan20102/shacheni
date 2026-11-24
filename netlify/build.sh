#!/usr/bin/env bash
# Netlify build: install Flutter (pinned to the version used in development), then build the web
# app with the Supabase settings from Netlify environment variables. Run from the repo root.
# Crash reporting (app/lib/app/crash_reporting.dart) sends to Naybor's Sentry project by default.
# The DSN is a public "send-only" address, not a secret. Set SENTRY_DSN in Netlify to override it,
# or set it to an empty value to turn crash reporting off.
NAYBOR_SENTRY_DSN="https://bb13c30050222881fce40decc68d563e@o4512487601143808.ingest.de.sentry.io/4512487615889488"
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
  "SUPABASE_PUBLISHABLE_KEY": "$SUPABASE_PUBLISHABLE_KEY",
  "SENTRY_DSN": "${SENTRY_DSN-$NAYBOR_SENTRY_DSN}",
  "SENTRY_ENVIRONMENT": "${SENTRY_ENVIRONMENT:-${CONTEXT:-production}}"
}
EOF
flutter pub get
flutter build web --release --dart-define-from-file=config/netlify.json
