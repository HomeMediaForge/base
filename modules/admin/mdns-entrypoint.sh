#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${MDNS_CONFIG_PATH:-/etc/mdns/config.hcl}"
WATCH_DIR="$(dirname "${CONFIG_PATH}")"
SLEEP_AFTER_RELOAD="${MDNS_REFRESH_WAIT:-1}"

mkdir -p "${WATCH_DIR}"
touch "${CONFIG_PATH}"

BIND_IP="${HMF_MDNS_BIND_ADDRESS:-${MDNS_BIND_ADDRESS:-}}"
DEFAULT_COLLISION="${HMF_MDNS_COLLISION_STRATEGY:-hostname}"

if [[ ! -s "${CONFIG_PATH}" ]]; then
  if [[ -n "${BIND_IP}" ]]; then
    cat > "${CONFIG_PATH}" <<EOF
bind_address = "${BIND_IP}"
collision_avoidance = "${DEFAULT_COLLISION}"
EOF
  else
    cat > "${CONFIG_PATH}" <<'EOF'
# mdns-publisher: bind_address vacío. Establece HMF_MDNS_BIND_ADDRESS en tu .env
EOF
  fi
fi

terminate_children() {
  pkill -TERM -P $$ >/dev/null 2>&1 || true
  wait >/dev/null 2>&1 || true
}

trap 'terminate_children; exit 0' INT TERM

while true; do
  echo "[mdns-entrypoint] Starting mdns-publisher with ${CONFIG_PATH}"
  mdns-publisher publish --config "${CONFIG_PATH}" &
  PUBLISHER_PID=$!

  inotifywait -q -e modify,create,delete,move "${WATCH_DIR}" >/dev/null 2>&1 &
  WATCHER_PID=$!

  set +e
  wait -n "${PUBLISHER_PID}" "${WATCHER_PID}"
  set -e

  kill -TERM "${PUBLISHER_PID}" >/dev/null 2>&1 || true
  wait "${PUBLISHER_PID}" >/dev/null 2>&1 || true
  kill "${WATCHER_PID}" >/dev/null 2>&1 || true

  echo "[mdns-entrypoint] Reload triggered, restarting mdns-publisher..."
  sleep "${SLEEP_AFTER_RELOAD}"
done
