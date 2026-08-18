#!/usr/bin/env bash
# Compile BANTADS apps one at a time to keep RAM low (backend MSs + gateway + frontend).
# Usage: ./compile-services.sh
#        ./compile-services.sh --test
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SERVICES="$ROOT/backend/services"
GATEWAY="$ROOT/backend/gateway"
FRONTEND="$ROOT/frontend"
WITH_TEST=false

if [[ "${1:-}" == "--test" ]]; then
  WITH_TEST=true
fi

GRADLE_OPTS=(--no-daemon --no-parallel --max-workers=1)

gradlew() {
  if [[ -x "$SERVICES/gradlew" ]]; then
    "$SERVICES/gradlew" "${GRADLE_OPTS[@]}" "$@"
  else
    "$SERVICES/gradlew.bat" "${GRADLE_OPTS[@]}" "$@"
  fi
}

compile_npm() {
  local name="$1"
  local dir="$2"
  if [[ ! -f "$dir/package.json" ]]; then
    echo "==> $name (skipped, not present yet)"
    return 0
  fi
  echo "==> $name"
  (
    cd "$dir"
    if [[ ! -d node_modules ]]; then
      npm ci
    fi
    npm run build
    if [[ "$WITH_TEST" == true ]] && node -e "process.exit(require('./package.json').scripts && require('./package.json').scripts.test ? 0 : 1)"; then
      npm test -- --watch=false
    fi
  )
}

echo "==> stopping leftover Gradle daemon"
(cd "$SERVICES" && ./gradlew --stop >/dev/null 2>&1 || true)

echo "==> shared"
(cd "$SERVICES" && gradlew :shared:jar)
if [[ "$WITH_TEST" == true ]]; then
  (cd "$SERVICES" && gradlew :shared:test)
fi

for module in auth cliente gerente conta saga email; do
  echo "==> $module"
  (cd "$SERVICES" && gradlew ":${module}:bootJar")
  if [[ "$WITH_TEST" == true ]]; then
    (cd "$SERVICES" && gradlew ":${module}:test")
  fi
done

compile_npm gateway "$GATEWAY"
compile_npm frontend "$FRONTEND"

echo "==> done (sequential compile)"
