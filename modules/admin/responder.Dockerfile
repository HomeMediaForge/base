# ======================================================
# 🧩 HomeMediaForge NBNS / LLMNR Responder (Windows Discovery)
# Basado en Alpine + Python 3 + Responder (LGandx)
# ======================================================

# Imagen base ligera
FROM alpine:3.20

# ------------------------------------------------------
# 1️⃣ Instalar dependencias necesarias para Python y compilación mínima
# ------------------------------------------------------
RUN apk add --no-cache \
  python3 py3-pip git bash gcc musl-dev libffi-dev openssl-dev

# ------------------------------------------------------
# 2️⃣ Clonar el verdadero Responder desde GitHub (LGandx)
# ------------------------------------------------------
RUN git clone https://github.com/lgandx/Responder.git /opt/Responder

# ------------------------------------------------------
# 3️⃣ Crear usuario no-root por seguridad
# ------------------------------------------------------
RUN adduser -D -g '' responder

# ------------------------------------------------------
# 4️⃣ (Opcional) Limpiar compiladores y paquetes pesados para reducir tamaño
# ------------------------------------------------------
RUN apk del git gcc musl-dev libffi-dev openssl-dev

# ------------------------------------------------------
# 5️⃣ Directorio de trabajo
# ------------------------------------------------------
WORKDIR /opt/Responder

# ------------------------------------------------------
# 6️⃣ Ejecutar como usuario sin privilegios
# ------------------------------------------------------
USER responder

# ------------------------------------------------------
# 7️⃣ Comando por defecto: iniciar Responder escuchando en eth0
# ------------------------------------------------------
ENTRYPOINT ["python3", "Responder.py", "-I", "eth0", "-w", "Off", "-r", "Off", "-d", "Off"]
