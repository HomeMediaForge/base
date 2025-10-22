# ======================================================
# 🧩 HomeMediaForge NBNS / LLMNR Responder (Windows Discovery)
# ======================================================
FROM alpine:3.20

# 1️⃣ Instalar dependencias para compilar netifaces + Python
RUN apk add --no-cache \
  python3 py3-pip python3-dev git bash gcc musl-dev libffi-dev openssl-dev linux-headers

# 2️⃣ Clonar Responder
RUN git clone https://github.com/lgandx/Responder.git /opt/Responder

# 3️⃣ Instalar netifaces (PEP 668-safe)
RUN pip install --break-system-packages netifaces

# 4️⃣ Crear usuario sin privilegios
RUN adduser -D -g '' responder

# 5️⃣ (Opcional) limpiar compiladores
RUN apk del git gcc musl-dev libffi-dev openssl-dev linux-headers python3-dev

WORKDIR /opt/Responder
USER responder

ENTRYPOINT ["python3", "Responder.py", "-I", "eth0", "-w", "Off", "-r", "Off", "-d", "Off"]
