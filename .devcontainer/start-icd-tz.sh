#!/usr/bin/env bash
set -euo pipefail

require_env() {
  local name

  for name in "$@"; do
    if [ -z "${!name:-}" ]; then
      echo "$name must be set by the Dev Container environment." >&2
      echo "Defaults live in .devcontainer/docker-compose.yml." >&2
      exit 1
    fi
  done
}

require_env BENCH_ROOT BENCH_NAME

BENCH_DIR="${BENCH_ROOT}/${BENCH_NAME}"
APP_URL="${APP_URL:-http://127.0.0.1:8000/app/icd}"

if pgrep -f "honcho start" >/dev/null; then
  cat <<EOF
ICD-TZ Bench is already running.

Open:
  $APP_URL
EOF
  exit 0
fi

cd "$BENCH_DIR"
bench start
