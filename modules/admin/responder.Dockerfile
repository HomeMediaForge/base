# ======================================================
# 🧩 HomeMediaForge NBNS / LLMNR Responder (Windows Discovery)
# ======================================================
FROM alpine:3.20

# 1️⃣ Dependencias de compilación + Python
RUN apk add --no-cache \
  python3 py3-pip git bash gcc musl-dev libffi-dev openssl-dev linux-headers

# 2️⃣ Clonar el Responder oficial
RUN git clone https://github.com/lgandx/Responder.git /opt/Responder

# 3️⃣ Instalar dependencia requerida
RUN pip install netifaces

# 4️⃣ Crear usuario sin privilegios
RUN adduser -D -g '' responder

# 5️⃣ (Opcional) limpiar compiladores después de instalar netifaces
RUN apk del git gcc musl-dev libffi-dev openssl-dev linux-headers

WORKDIR /opt/Responder
USER responder

ENTRYPOINT ["python3", "Responder.py", "-I", "eth0", "-w", "Off", "-r", "Off", "-d", "Off"]
