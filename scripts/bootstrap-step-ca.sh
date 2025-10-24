#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a smallstep/step-ca instance inside ${STACK_CONFIG_DIR}/step-ca
# Generates passwords (if missing), runs `step ca init` and enforces DNS policy.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_CONFIG_DIR="${STACK_CONFIG_DIR:-${ROOT_DIR}/config}"

STEP_CA_DIR="${STACK_CONFIG_DIR}/step-ca"
CONFIG_DIR="${STEP_CA_DIR}/config"
CERTS_DIR="${STEP_CA_DIR}/certs"
SECRETS_DIR="${STEP_CA_DIR}/secrets"
DB_DIR="${STEP_CA_DIR}/db"

STEP_CA_VERSION="${STEP_CA_VERSION:-0.28.0}"
STEP_CA_NAME="${STEP_CA_NAME:-HomeMediaForge Internal CA}"
STEP_CA_DNS="${STEP_CA_DNS:-ca.local}"
STEP_CA_LISTEN_ADDR="${STEP_CA_LISTEN_ADDR:-0.0.0.0:9000}"
STEP_CA_ACME_PROVISIONER="${STEP_CA_ACME_PROVISIONER:-hmf-acme}"
STEP_CA_ACME_EMAIL="${STEP_CA_ACME_EMAIL:-admin@homemediaforge.local}"
STEP_CA_ALLOWED_SANS="${STEP_CA_ALLOWED_SANS:-*.local,*.homemediaforge.local,homemediaforge.local,local}"

mkdir -p "${CONFIG_DIR}" "${CERTS_DIR}" "${SECRETS_DIR}" "${DB_DIR}"

PASS_FILE="${SECRETS_DIR}/password.txt"
PROV_PASS_FILE="${SECRETS_DIR}/provisioner_password.txt"

generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 36
  else
    head -c 48 /dev/urandom | base64
  fi
}

if [[ ! -s "${PASS_FILE}" ]]; then
  umask 177
  generate_password > "${PASS_FILE}"
  echo "✓ Generado password.txt"
fi

if [[ ! -s "${PROV_PASS_FILE}" ]]; then
  umask 177
  cp "${PASS_FILE}" "${PROV_PASS_FILE}"
  echo "✓ Generado provisioner_password.txt"
fi

if [[ ! -f "${CONFIG_DIR}/ca.json" ]]; then
  DNS_FLAGS=()
  IFS=',' read -ra DNS_ENTRIES <<< "${STEP_CA_DNS}"
  for dns in "${DNS_ENTRIES[@]}"; do
    dns_trimmed="$(echo "${dns}" | xargs)"
    [[ -n "${dns_trimmed}" ]] && DNS_FLAGS+=(--dns "${dns_trimmed}")
  done

  docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "${STEP_CA_DIR}:/home/step" \
    "smallstep/step-ca:${STEP_CA_VERSION}" \
    step ca init \
      --name "${STEP_CA_NAME}" \
      "${DNS_FLAGS[@]}" \
      --address "${STEP_CA_LISTEN_ADDR}" \
      --provisioner "${STEP_CA_ACME_PROVISIONER}" \
      --provisioner-password-file /home/step/secrets/provisioner_password.txt \
      --password-file /home/step/secrets/password.txt \
      --acme \
      --deployment-type standalone
  echo "✓ step-ca inicializado en ${STEP_CA_DIR}"
else
  echo "• step-ca ya inicializado, actualizando configuración"
fi

python3 - <<PY
import json
from pathlib import Path

config_path = Path("${CONFIG_DIR}") / "ca.json"
if not config_path.exists():
    raise SystemExit("Config ca.json no existe; ejecuta step ca init primero.")

allowed = [entry.strip() for entry in "${STEP_CA_ALLOWED_SANS}".split(",") if entry.strip()]
if not allowed:
    raise SystemExit("STEP_CA_ALLOWED_SANS sin entradas válidas")

with config_path.open(encoding="utf-8") as fh:
    data = json.load(fh)

policy = data.setdefault("policy", {}).setdefault("x509", {}).setdefault("allow", {})
policy["dns"] = allowed

provisioners = data.get("authority", {}).get("provisioners", [])
for prov in provisioners:
    if prov.get("type") == "ACME" and prov.get("name") == "${STEP_CA_ACME_PROVISIONER}":
        claims = prov.setdefault("claims", {})
        claims["allowAnonymous"] = True
        claims["allowWildcardNames"] = True
        claims["allowDNS"] = allowed

with config_path.open("w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\\n")
PY

echo "✓ Política de dominios actualizada"
echo "→ Copia ${CERTS_DIR}/root_ca.crt en tus clientes y añádelo a los certificados raíz de confianza."
