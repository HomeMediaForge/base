#!/bin/bash
# ==========================================================
# 🧩 generate-env.sh
# ----------------------------------------------------------
# Genera un archivo .env expandido a partir de env.template
# Expande variables anidadas (p.ej. ${STACK_ROOT}/config)
# para compatibilidad total con Docker Compose y Portainer.
# ----------------------------------------------------------
# ✅ Detecta automáticamente la carpeta base (un nivel arriba)
# ✅ Funciona desde cualquier ubicación
# ✅ Muestra vista previa del resultado
# ==========================================================

set -e  # Detener en caso de error

# Detectar ubicación del script y calcular BASE_DIR (un nivel superior)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Definir rutas de template y salida
TEMPLATE_FILE="${BASE_DIR}/env.template"
OUTPUT_FILE="${BASE_DIR}/.env"

echo "📂 BASE_DIR detectado: ${BASE_DIR}"
echo "🧾 Template: ${TEMPLATE_FILE}"
echo "🧾 Salida:   ${OUTPUT_FILE}"
echo

# Verificar que el template exista
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ No se encontró ${TEMPLATE_FILE}"
    echo "   Asegúrate de tener env.template en la carpeta base del stack."
    exit 1
fi

# Cargar y exportar variables definidas en el template
set -a
source "$TEMPLATE_FILE"
set +a

# Exportar todas las claves declaradas (para que envsubst funcione)
export $(grep -v '^#' "$TEMPLATE_FILE" | sed -E 's/=.*//' | xargs)

# Generar archivo expandido
echo "🔧 Generando .env expandido desde env.template..."
envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

# Mostrar resumen de resultado
echo
echo "✅ .env generado correctamente en: $OUTPUT_FILE"
echo
echo "Primeras líneas:"
head -n 10 "$OUTPUT_FILE"
echo "..."
echo
echo "ℹ️ Para validar las variables expandidas:"
echo "   docker compose --env-file ${OUTPUT_FILE} config"
echo
echo "🚀 Listo. Usa el .env expandido en tus despliegues."
