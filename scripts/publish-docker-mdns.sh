#!/bin/bash
SERVICES_DIR="/etc/avahi/services"

for svc in jellyfin radarr sonarr organizr; do
  port=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' $svc 2>/dev/null)
  if [ -n "$port" ]; then
    cat > "$SERVICES_DIR/$svc.service" <<EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">${svc^}</name>
  <service>
    <type>_http._tcp</type>
    <port>$port</port>
  </service>
</service-group>
EOF
  fi
done

systemctl restart avahi-daemon
