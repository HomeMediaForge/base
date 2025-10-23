#!/bin/bash
# ===============================================================
# 🏠 HomeMediaForge - Generador de certificados con CA propia
# ---------------------------------------------------------------
# Mantiene nombres hmf.crt / hmf.key, genera CA raíz y firma dominios locales
# Ruta destino: config-templates/traefik/certs
# ===============================================================

set -e

# === Configuración ===
BASE_DIR="$(pwd)"
CERT_DIR="${BASE_DIR}/config-templates/traefik/certs"
DAYS_CA=3650   # 10 años
DAYS_CERT=3650  # 10 años
HMF_HOST_SEGMENT="${HMF_HOST_SEGMENT:-${HOSTNAME:-homemediaforge}}"
HMF_LOCAL_DOMAIN="${TRAEFIK_LOCAL_DOMAIN:-local}"
HMF_WILDCARD="*.${HMF_HOST_SEGMENT}.${HMF_LOCAL_DOMAIN}"
HMF_BASE_DOMAIN="${HMF_HOST_SEGMENT}.${HMF_LOCAL_DOMAIN}"

# Archivos de salida
CA_KEY="${CERT_DIR}/hmf-rootCA.key"
CA_CRT="${CERT_DIR}/hmf-rootCA.crt"
CERT_KEY="${CERT_DIR}/hmf.key"
CERT_CSR="${CERT_DIR}/hmf.csr"
CERT_CRT="${CERT_DIR}/hmf.crt"
CERT_EXT="${CERT_DIR}/hmf.ext"

# Crear carpeta si no existe
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "📁 Generando certificados en: $CERT_DIR"

# === 1️⃣ Crear CA raíz si no existe ===
if [[ ! -f "$CA_KEY" || ! -f "$CA_CRT" ]]; then
  echo "🏛️  Creando HomeMediaForge Root CA..."
  openssl genrsa -out "$CA_KEY" 4096
  openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days $DAYS_CA -out "$CA_CRT" \
    -subj "/C=CL/ST=Valparaiso/L=Vina del Mar/O=HomeMediaForge/CN=HomeMediaForge Root CA"
else
  echo "✅ CA raíz existente detectada, reutilizando."
fi

# === 2️⃣ Crear o reutilizar la clave del certificado ===
if [[ ! -f "$CERT_KEY" ]]; then
  echo "🔏 Generando nueva clave privada hmf.key..."
  openssl genrsa -out "$CERT_KEY" 2048
else
  echo "✅ Clave hmf.key existente detectada, se mantendrá."
fi

# === 3️⃣ Crear CSR (solicitud de firma) ===
echo "📜 Generando CSR para ${HMF_WILDCARD}..."
openssl req -new -key "$CERT_KEY" -out "$CERT_CSR" \
  -subj "/C=CL/ST=Valparaiso/L=Vina del Mar/O=HomeMediaForge/CN=${HMF_WILDCARD}"

# === 4️⃣ Crear archivo de extensiones SAN ===
cat > "$CERT_EXT" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${HMF_WILDCARD}
DNS.2 = ${HMF_BASE_DOMAIN}
DNS.3 = localhost
EOF

# === 5️⃣ Firmar el certificado con la CA ===
echo "🧾 Firmando certificado hmf.crt con CA raíz..."
openssl x509 -req -in "$CERT_CSR" -CA "$CA_CRT" -CAkey "$CA_KEY" \
  -CAcreateserial -out "$CERT_CRT" -days $DAYS_CERT -sha256 -extfile "$CERT_EXT"

# === 6️⃣ Permisos ===
chmod 600 "$CA_KEY" "$CERT_KEY"
chmod 644 "$CA_CRT" "$CERT_CRT"

# === 7️⃣ Resumen ===
echo ""
echo "✅ Certificados generados correctamente:"
openssl x509 -in "$CERT_CRT" -noout -subject -issuer
echo ""
echo "📦 Archivos generados:"
ls -1 "$CERT_DIR" | grep -E 'hmf|rootCA'
echo ""
echo "🪟 👉 Instala la CA raíz en Windows ejecutando:"
echo "    certutil -addstore -f \"Root\" \"C:\\hmf-rootCA.crt\""
echo ""
echo "🔁 Luego reinicia Traefik:"
echo "    docker restart traefik"
echo ""
echo "🧠 Resultado esperado:"
echo "   https://sonarr.${HMF_BASE_DOMAIN} → 'Emitido por: HomeMediaForge Root CA'"
