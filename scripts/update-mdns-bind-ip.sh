#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-${HMF_NETWORK_INTERFACE:-}}"
RESTART=false
COMPOSE_DIR="${COMPOSE_DIR:-${ROOT_DIR}}"
COMPOSE_CMD="${COMPOSE_CMD:-docker compose}"
SERVICES="${SERVICES:-mdns}"

usage() {
  cat <<'EOF'
Usage: update-mdns-bind-ip.sh [options]

Detects the current IPv4 LAN address of the host, updates HMF_MDNS_BIND_ADDRESS
in the target .env file, and optionally restarts the mdns service.

Options:
  --env-file <path>      Path to the .env file (default: ./ .env)
  --interface <iface>    Network interface to query (default: auto via route)
  --compose-dir <path>   Directory where docker compose is executed (default: repo root)
  --compose-cmd <cmd>    Compose command (default: "docker compose")
  --services "<list>"    Services to restart when --restart is used (default: "mdns")
  --restart              Restart services after updating the IP
  -h, --help             Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    --interface)
      NETWORK_INTERFACE="$2"
      shift 2
      ;;
    --compose-dir)
      COMPOSE_DIR="$2"
      shift 2
      ;;
    --compose-cmd)
      COMPOSE_CMD="$2"
      shift 2
      ;;
    --services)
      SERVICES="$2"
      shift 2
      ;;
    --restart)
      RESTART=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "⚠️  No se encontró el archivo .env en ${ENV_FILE}" >&2
  exit 1
fi

detect_ip() {
  if [[ -n "${NETWORK_INTERFACE}" ]]; then
    ip -o -4 addr show dev "${NETWORK_INTERFACE}" | awk '{split($4,a,"/"); print a[1]; exit}'
  else
    ip -4 route get 1 | awk '{for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}'
  fi
}

CURRENT_IP="$(detect_ip || true)"

if [[ -z "${CURRENT_IP}" ]]; then
  echo "❌ No se pudo detectar la IP actual. Revisa la interfaz o conectividad." >&2
  exit 1
fi

EXISTING_VALUE="$(grep -E '^HMF_MDNS_BIND_ADDRESS=' "${ENV_FILE}" | head -n1 | cut -d= -f2- || true)"

if [[ "${EXISTING_VALUE}" == "${CURRENT_IP}" ]]; then
  echo "✅ HMF_MDNS_BIND_ADDRESS ya está configurado en ${CURRENT_IP}. Nada que hacer."
  exit 0
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "${TMP_FILE}"' EXIT

if grep -qE '^HMF_MDNS_BIND_ADDRESS=' "${ENV_FILE}"; then
  awk -v ip="${CURRENT_IP}" '
    $0 ~ /^HMF_MDNS_BIND_ADDRESS=/ { print "HMF_MDNS_BIND_ADDRESS=" ip; next }
    { print }
  ' "${ENV_FILE}" > "${TMP_FILE}"
else
  cat "${ENV_FILE}" > "${TMP_FILE}"
  echo "HMF_MDNS_BIND_ADDRESS=${CURRENT_IP}" >> "${TMP_FILE}"
fi

mv "${TMP_FILE}" "${ENV_FILE}"
echo "🔄 HMF_MDNS_BIND_ADDRESS actualizado a ${CURRENT_IP} en ${ENV_FILE}"

if [[ "${RESTART}" == true ]]; then
  IFS=' ' read -r -a COMPOSE_ARR <<< "${COMPOSE_CMD}"
  echo "🚀 Reiniciando servicios (${SERVICES}) con ${COMPOSE_CMD}..."
  (cd "${COMPOSE_DIR}" && "${COMPOSE_ARR[@]}" up -d ${SERVICES})
fi
