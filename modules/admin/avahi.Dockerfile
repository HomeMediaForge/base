# ============================================
# 🧩 HomeMediaForge - Avahi mDNS Reflector
# ============================================
FROM alpine:3.20

RUN apk add --no-cache avahi dbus
COPY avahi-daemon.conf /etc/avahi/avahi-daemon.conf

ENTRYPOINT ["/usr/sbin/avahi-daemon","--no-drop-root","--debug"]
