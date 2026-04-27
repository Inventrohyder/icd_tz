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

require_env \
  SITE \
  ADMIN_PASSWORD \
  FRAPPE_BRANCH \
  ERPNEXT_BRANCH \
  BENCH_ROOT \
  BENCH_NAME \
  APP_SRC \
  PYTHON_BIN \
  DB_HOST \
  DB_PORT \
  DB_ROOT_USER \
  DB_ROOT_PASSWORD \
  REDIS_CACHE_URL \
  REDIS_QUEUE_URL \
  REDIS_SOCKETIO_URL \
  PIP_DEFAULT_TIMEOUT \
  UV_CACHE_DIR \
  UV_HTTP_TIMEOUT \
  UV_LINK_MODE

BENCH_DIR="$BENCH_ROOT/$BENCH_NAME"

export PIP_DEFAULT_TIMEOUT
export UV_CACHE_DIR
export UV_HTTP_TIMEOUT
export UV_LINK_MODE

log() {
  printf '\n==> %s\n' "$*"
}

retry() {
  local attempt
  for attempt in 1 2 3; do
    "$@" && return 0
    echo "Command failed on attempt $attempt: $*" >&2
    sleep "$((attempt * 10))"
  done
  "$@"
}

ensure_writable_dir() {
  local path="$1"
  local label="$2"

  if command -v sudo >/dev/null; then
    sudo mkdir -p "$path"
  else
    mkdir -p "$path"
  fi

  if [ -w "$path" ]; then
    return
  fi

  if ! command -v sudo >/dev/null; then
    echo "$path is not writable and sudo is not available." >&2
    exit 1
  fi

  log "Taking ownership of $label"
  sudo chown -R "$(id -u):$(id -g)" "$path"
}

ensure_bench_root() {
  ensure_writable_dir "$BENCH_ROOT" "generated Bench volume"
}

ensure_dependency_caches() {
  ensure_writable_dir "$UV_CACHE_DIR" "uv cache volume"
}

ensure_bench() {
  ensure_bench_root
  cd "$BENCH_ROOT"

  if [ -d "$BENCH_DIR/apps/frappe" ]; then
    return
  fi

  log "Creating Frappe bench on $FRAPPE_BRANCH"
  retry bench init "$BENCH_NAME" \
    --frappe-branch "$FRAPPE_BRANCH" \
    --python "$PYTHON_BIN" \
    --skip-redis-config-generation \
    --skip-assets
}

ensure_python_environment() {
  # Bench data survives container rebuilds, so verify the virtualenv still matches the image.
  if env/bin/python - <<'PY'
import frappe
PY
  then
    return
  fi

  log "Repairing Python environment"
  uv venv env --clear --seed --python "$PYTHON_BIN"
  retry bench setup requirements --python
}

configure_bench_services() {
  log "Configuring database and Redis services"
  bench set-config -g db_host "$DB_HOST"
  bench set-config -g db_port "$DB_PORT"
  bench set-config -g redis_cache "$REDIS_CACHE_URL"
  bench set-config -g redis_queue "$REDIS_QUEUE_URL"
  bench set-config -g redis_socketio "$REDIS_SOCKETIO_URL"
  bench set-config -gp developer_mode 1
}

ensure_erpnext_app() {
  if [ -d apps/erpnext ]; then
    return
  fi

  # App downloads live in the persistent Bench volume, not in Docker image layers.
  log "Installing ERPNext from $ERPNEXT_BRANCH"
  retry bench get-app --branch "$ERPNEXT_BRANCH" erpnext --skip-assets
}

ensure_icd_tz_app() {
  log "Linking local ICD-TZ app with bench get-app"

  if [ -L apps/icd_tz ] && [ "$(readlink apps/icd_tz)" != "$APP_SRC" ]; then
    rm -f apps/icd_tz
  fi

  if [ -e apps/icd_tz ] && [ ! -L apps/icd_tz ]; then
    rm -rf apps/icd_tz
  fi

  retry bench get-app --overwrite --soft-link icd_tz "$APP_SRC" --skip-assets
}

site_exists() {
  [ -d "sites/$SITE" ] && bench --site "$SITE" list-apps >/dev/null 2>&1
}

ensure_site() {
  if site_exists; then
    return
  fi

  log "Creating Frappe site $SITE"
  retry bench new-site "$SITE" \
    --db-host "$DB_HOST" \
    --mariadb-root-username "$DB_ROOT_USER" \
    --mariadb-root-password "$DB_ROOT_PASSWORD" \
    --mariadb-user-host-login-scope=% \
    --admin-password "$ADMIN_PASSWORD" \
    --force \
    --set-default
}

site_has_app() {
  bench --site "$SITE" list-apps | awk 'NF { print $1 }' | grep -qx "$1"
}

ensure_site_app() {
  local app="$1"

  if site_has_app "$app"; then
    return
  fi

  log "Installing $app on $SITE"
  bench --site "$SITE" install-app "$app"
}

build_assets() {
  log "Running migrations and final asset build"
  bench --site "$SITE" set-config developer_mode 1
  bench --site "$SITE" migrate
  retry bench setup requirements --node
  bench build
}

print_ready_message() {
  cat <<EOF

ICD-TZ dev container is ready.

Run:
  cd $BENCH_DIR
  bench start

Open:
  http://127.0.0.1:8000/app/icd

Login:
  Administrator / $ADMIN_PASSWORD
EOF
}

ensure_dependency_caches
ensure_bench
cd "$BENCH_DIR"
ensure_python_environment
configure_bench_services
ensure_erpnext_app
ensure_icd_tz_app
ensure_site
ensure_site_app erpnext
ensure_site_app icd_tz
build_assets
print_ready_message
