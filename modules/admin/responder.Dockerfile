# ======================================================
# 🧩 HomeMediaForge NBNS / LLMNR Responder (Windows Discovery)
# ======================================================
FROM alpine:3.20

# 1️⃣ Dependencias para compilar netifaces + aioquic + Python
RUN apk add --no-cache \
  python3 py3-pip python3-dev git bash gcc musl-dev libffi-dev openssl-dev linux-headers

# 2️⃣ Clonar Responder
RUN git clone https://github.com/lgandx/Responder.git /opt/Responder

# 3️⃣ Instalar dependencias requeridas
RUN pip install --break-system-packages netifaces aioquic

# 4️⃣ Crear usuario sin privilegios
RUN adduser -D -g '' responder

# 5️⃣ (Opcional) limpiar compiladores y cabeceras
RUN apk del git gcc musl-dev libffi-dev openssl-dev linux-headers python3-dev

WORKDIR /opt/Responder
USER responder

ENTRYPOINT ["python3", "Responder.py", "-I", "eth0", "-w", "Off", "-d", "Off"]
