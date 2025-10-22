# ============================
# 🧩 HomeMediaForge NBNS/LLMNR Responder
# Basado en Alpine + Python responder
# ============================
FROM alpine:3.20

RUN apk add --no-cache python3 py3-pip && \
  pip install --break-system-packages responder && \
  adduser -D -g '' responder

USER responder
CMD ["responder", "-I", "eth0", "-w", "Off", "-r", "Off", "-d", "Off"]
