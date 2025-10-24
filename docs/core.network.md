# 🌐 HomeMediaForge - Core Network Module (`core.network.yml`)

> Módulo base del ecosistema HomeMediaForge encargado de la **resolución local automática de nombres de contenedores** (`*.local`), permitiendo descubrimiento y acceso sin modificar el router ni los DNS del cliente.

---

## 📦 Objetivo General

Implementar un **bridge de red inteligente** que unifique los protocolos:
- **DNS** (para resoluciones estándar de red),
- **mDNS** (para descubrimiento multicast en macOS y Linux),
- **LLMNR / NetBIOS-NS** (para compatibilidad con Windows 10/11).

De esta forma, todos los equipos dentro de la LAN pueden acceder a los servicios de HomeMediaForge usando nombres locales del tipo:

http://plex.local
http://radarr.local
http://portainer.local
http://media.local

yaml
Copiar código

---

## 🧱 Arquitectura del Módulo

┌───────────────────────────┐
│ Clientes LAN │
│───────────────────────────│
│ Windows → LLMNR/NBNS │
│ Linux/macOS → mDNS │
│ Todos → DNS estándar │
└─────────────┬─────────────┘
│
(UDP 53 / 5353 / 5355)
│
┌─────────────┴────────────────────────┐
│ HomeMediaForge Stack                 │
│──────────────────────────────────────│
│ 🧠 dnsbridge → DNS local (dnsmasq)   │
│ 🧩 dnswatcher → auto-registro Docker │
│ 📣 avahi → mDNS reflector            │          
│ 💬 nbns → LLMNR/NBNS responder       │
└──────────────────────────────────────┘


---

## 🧠 `dnsbridge` — DNS Bridge Interno

**Imagen:** `jpillora/dnsmasq:latest`  
**Modo de red:** `host`  
**Puerto:** 53 (por defecto) o 5353 (modo compatibilidad)

### Función:
Servidor DNS ligero que:
- Resuelve dominios `*.local` para los contenedores activos.
- Reenvía consultas externas a servidores públicos (`1.1.1.1`, `8.8.8.8`).
- Se recarga dinámicamente cuando cambian los contenedores.

### Configuración clave:
```yaml
dnsbridge:
  image: jpillora/dnsmasq:latest
  network_mode: host
  volumes:
    - ${STACK_CONFIG_DIR}/dnsmasq:/etc/dnsmasq.d
  command:
    - "--local=/local/"
    - "--expand-hosts"
    - "--addn-hosts=/etc/dnsmasq.d/99-containers.conf"
    - "--address=/.local/127.0.0.1"
Archivos generados:
swift
Copiar código
/srv/homemediaforge/config/dnsmasq/d/99-containers.conf
Ejemplo:

ini
Copiar código
address=/radarr.local/172.18.0.12
address=/radarr.homemediaforge.local/172.18.0.12
address=/jellyfin.local/172.18.0.13
address=/jellyfin.homemediaforge.local/172.18.0.13
Logs esperados:
pgsql
Copiar código
dnsmasq: started, version 2.80 cachesize 150
dnsmasq: using local addresses only for domain local
🧩 dnswatcher — Auto-Registro de Contenedores
Imagen: jwilder/docker-gen

Función:
Escucha los eventos del socket Docker.

Regenera 99-containers.conf y `/etc/avahi/hosts` cuando se inicia o detiene un contenedor.

Notifica a dnsbridge mediante señal SIGHUP.

Configuración clave:
yaml
Copiar código
dnswatcher:
  image: jwilder/docker-gen
  depends_on:
    - dnsbridge
  volumes:
    - /var/run/docker.sock:/tmp/docker.sock:ro
    - ${STACK_CONFIG_DIR}/dnsmasq:/etc/dnsmasq
  command: >
    -notify-sighup dnsbridge
    -watch /etc/dnsmasq/dnsmasq.template
    /etc/dnsmasq/d/99-containers.conf
Logs esperados:
pgsql
Copiar código
Generated '/etc/dnsmasq/d/99-containers.conf' from 2 containers
Sending container 'dnsbridge' signal '1'
Watching docker events
📣 avahi — mDNS Reflector
Dockerfile: modules/admin/avahi.Dockerfile

Función:
Publica el nombre del host (media.local) por multicast.

Permite descubrimiento automático en macOS/Linux.

Refleja los anuncios mDNS en múltiples subredes.

Archivos relevantes:

/opt/HomeMediaForge/modules/admin/avahi-daemon.conf
Ejemplo simplificado:


[server]
host-name=media
use-ipv4=yes
allow-interfaces=eth0
publish-workstation=yes
enable-reflector=yes
enable-dbus=no
Logs esperados:
pgsql
Copiar código
avahi-daemon 0.8 starting up.
Server startup complete. Host name is media.local.

📡 mdns — mDNS Publisher
Dockerfile: modules/admin/mdns.Dockerfile

Función:
Genera anuncios mDNS dinámicos (`contenedor.local` y `contenedor.<hostname>.local`) con `mdns-publisher`, eliminando la necesidad de crear archivos `.service` a mano.

Requisitos previos:
- Define `HMF_MDNS_BIND_ADDRESS` en `.env` con la IP LAN del host.
- Copia `config-templates/mdns/config.hcl.template` a `${STACK_CONFIG_DIR}/mdns/config.hcl.template`.
- (Opcional) Sobrescribe el puerto publicado añadiendo la etiqueta `hmf.mdns.port=<puerto>` al contenedor.

Configuración clave:
```yaml
mdns:
  build:
    context: /opt/HomeMediaForge/modules/admin
    dockerfile: mdns.Dockerfile
  network_mode: host
  volumes:
    - ${STACK_CONFIG_DIR}/mdns:/etc/mdns
```

Logs esperados:
```text
[mdns-entrypoint] Starting mdns-publisher with /etc/mdns/config.hcl
[mdns-entrypoint] Reload triggered, restarting mdns-publisher...
```

Automatiza la detección de IP:
- Ejecuta el helper `scripts/update-mdns-bind-ip.sh --restart` para actualizar `.env` y reiniciar `mdns`.
- Opcional: crea un timer de systemd que corra el script cada pocos minutos, por ejemplo:

```ini
# /etc/systemd/system/hmf-mdns-ip.service
[Unit]
Description=Actualiza HMF_MDNS_BIND_ADDRESS automáticamente

[Service]
Type=oneshot
ExecStart=/opt/HomeMediaForge/base.git/scripts/update-mdns-bind-ip.sh --env-file /opt/HomeMediaForge/base.git/.env --compose-dir /opt/HomeMediaForge/base.git --restart
```

```ini
# /etc/systemd/system/hmf-mdns-ip.timer
[Unit]
Description=Chequea cambios de IP para mdns-publisher

[Timer]
OnBootSec=2m
OnUnitActiveSec=5m

[Install]
WantedBy=timers.target
```

Actívalo con:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now hmf-mdns-ip.timer
```
⚠️ Ajusta las rutas anteriores según el directorio real donde tengas desplegada la stack.
💬 nbns — LLMNR / NetBIOS Responder (Windows Discovery)
Dockerfile: modules/admin/responder.Dockerfile

Función:
Atiende consultas Windows (UDP/5355 y UDP/137).

Permite resolución .local sin Bonjour.

Emula comportamiento WSD sin depender del router.

Logs esperados:
nginx
Copiar código
Responder 3.0.6 starting...
[+] Listening for LLMNR/NBNS requests on enp3s0
⚙️ Volúmenes utilizados
Carpeta host	Montaje en contenedor	Propósito
${STACK_CONFIG_DIR}/dnsmasq	/etc/dnsmasq.d	Archivos DNS dinámicos
${STACK_CONFIG_DIR}/avahi/services	/etc/avahi/services	Anuncios mDNS personalizados
${STACK_CONFIG_DIR}/avahi/hosts	/etc/avahi/hosts	Entradas mDNS dinámicas (contenedor.local y contenedor.<hostname>.local)
${STACK_CONFIG_DIR}/mdns	/etc/mdns	Config HCL autogenerado para mdns-publisher

🧩 Flujo de resolución
Cliente	Protocolo	Servicio	Resultado
Linux/macOS	mDNS	avahi	media.local responde
Windows	LLMNR/NBNS	nbns	media.local responde
Todos	DNS (53)	dnsbridge	*.local → contenedor
Docker interno	docker-gen	dnswatcher	DNS actualizado en caliente

🚀 Pruebas básicas
1️⃣ Desde el host
bash
Copiar código
ping radarr.local
dig @127.0.0.1 jellyfin.local
2️⃣ Desde otro contenedor
bash
Copiar código
docker exec -it radarr ping jellyfin.local
3️⃣ Desde Windows 11
powershell
Copiar código
ping media.local
Resolve-DnsName radarr.local -Server 192.168.99.10
🧰 Solución de problemas comunes
❌ dnsmasq: failed to create listening socket for port 53
Otro servicio (p. ej. systemd-resolved) ocupa el puerto 53.

Solución:

bash
Copiar código
sudo systemctl disable --now systemd-resolved
sudo rm /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
O cambia el puerto en core.network.yml:

yaml
Copiar código
--port=5353
❌ Windows + Tailscale rompe .local
Tailscale intercepta el DNS del sistema y bloquea multicast.

Soluciones posibles:

Forzar DNS local:

powershell
Copiar código
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses ("192.168.99.10","1.1.1.1")
O usar MagicDNS + Split DNS:
Redirigir .local hacia el IP del servidor (100.x.x.x o 192.168.99.10).

🏁 Estado actual de cada servicio
Servicio	Estado	Protocolo	Función
dnsbridge	✅ Estable	DNS	Bridge de resolución local
dnswatcher	✅ Estable	Docker socket	Auto-registro
avahi	✅ Estable	mDNS	Descubrimiento multicast
nbns	⚙️ En pruebas	LLMNR/NBNS	Descubrimiento Windows

🧩 Próximos pasos sugeridos
 Integrar dnsbridge con Traefik para certificados automáticos por hostname.

 Añadir healthchecks HTTP para cada subservicio.

 Agregar soporte IPv6 opcional.

 Publicar el módulo como core.network.yml v1.1 en el repo HomeMediaForge/base.

Autor:
🧑‍💻 José Manuel Gajardo
Proyecto: HomeMediaForge
Licencia: MIT
