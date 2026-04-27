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

pkill -TERM -f "honcho start" 2>/dev/null || true
sleep 2
pkill -TERM -f "frappe.app:application" 2>/dev/null || true
pkill -TERM -f "node esbuild --watch" 2>/dev/null || true

printf 'Stopped ICD-TZ Bench processes for %s when they were running.\n' "$BENCH_DIR"
