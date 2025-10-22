# ======================================================
# 🧩 HomeMediaForge NBNS / LLMNR Responder (Windows Discovery)
# ======================================================
FROM alpine:3.20

# 1️⃣ Dependencias para compilar netifaces + aioquic + Python
RUN apk add --no-cache \
  python3 py3-pip python3-dev git bash gcc musl-dev libffi-dev openssl-dev linux-headers

# 2️⃣ Clonar Responder
RUN git clone https://github.com/lgandx/Responder.git /opt/Responder

# 3️⃣ Instalar dependencias requeridas (con binarios compilables)
RUN pip install --break-system-packages netifaces aioquic

# 4️⃣ (Opcional) limpiar compiladores y headers para reducir tamaño
RUN apk del git gcc musl-dev libffi-dev openssl-dev linux-headers python3-dev

WORKDIR /opt/Responder

# 5️⃣ Permitir interfaz variable (pasada por env)
ENV NET_IFACE=enp0s3

# 6️⃣ Ejecutar en modo escucha total (LLMNR + NBNS + mDNS)
ENTRYPOINT ["sh", "-c", "python3 Responder.py -I ${NET_IFACE} -wd"]
