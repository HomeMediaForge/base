# 🏠 HomeMediaForge — Base Stack

**Build your home media cloud — modular, secure, self-hosted.**  
*La base modular de HomeMediaForge para tu nube multimedia doméstica.*

---

## 🚀 Descripción

**HomeMediaForge Base** es el *stack fundamental* sobre el que se construye toda la plataforma HomeMediaForge.  
Proporciona una infraestructura Docker Compose limpia, segura y modular para gestionar servicios multimedia, automatización y administración doméstica.

Diseñado para:
- 💻 Servidores personales o NAS
- 🧠 Usuarios avanzados que buscan un stack Docker estable y replicable
- ⚙️ Desarrolladores que quieran derivar versiones optimizadas (Intel, AMD, Lite…)

---

## 🧩 Arquitectura modular

homemediaforge/
┣ 📁 base/ # Stack genérico (este repositorio)
┣ 📁 intel/ # Optimizado para iGPU Intel (QuickSync, VAAPI)
┣ 📁 amd/ # Adaptado a GPUs AMD
┣ 📁 lite/ # Versión reducida para hardware limitado
┣ 📁 docs/ # Documentación (MkDocs/Docusaurus)
┗ 📁 installer/ # Scripts de instalación automatizada

yaml
Copiar código

---

## ⚙️ Características

- 🧱 Docker Compose modular  
- 🔒 Reverse Proxy con **SWAG + Cloudflare DNS**  
- ☁️ Backups en **Wasabi / Hetzner**  
- 🎞️ Transcodificación acelerada por GPU (Plex, Jellyfin)  
- 🧠 Automatización con Sonarr, Radarr, Bazarr, etc.  
- 🌍 Integración de red segura (LAN + Tailscale opcional)  
- 🔐 Cifrado TLS obligatorio y soporte para `.app` (HTTPS only)

---

## 🧰 Stack Base — Servicios incluidos

| Servicio | Propósito | Imagen |
|-----------|------------|--------|
| SWAG | Reverse Proxy + SSL | `lscr.io/linuxserver/swag` |
| Portainer | Administración Docker | `portainer/portainer-ce` |
| Sonarr / Radarr / Bazarr | Descarga y organización multimedia | `lscr.io/linuxserver/*` |
| Jellyfin | Servidor multimedia | `lscr.io/linuxserver/jellyfin` |
| Qbittorrent / Sabnzbd | Clientes de descarga | `lscr.io/linuxserver/*` |

*(La composición exacta depende de tu `.env` y módulos habilitados.)*

---

## 🧾 Ejemplo de despliegue

```bash
git clone https://github.com/homemediaforge/base.git
cd base
cp .env.example .env
docker compose up -d
💡 Asegúrate de configurar tus variables de entorno (PUID, PGID, TZ, STACK_CONFIG_DIR, etc.)

🌐 Enlaces oficiales
Sitio web: https://homemediaforge.app

Documentación: próximamente en docs.homemediaforge.app

Licencia: MIT

🧭 Roadmap
 Versión Intel (QuickSync + VAAPI)

 Versión AMD (ROCm)

 Versión Lite (Raspberry Pi / NAS)

 Sitio web con documentación (MkDocs)

 Script de instalación automática (installer)

🤝 Contribuir
¡Las contribuciones son bienvenidas!
Abre un issue o envía un pull request para mejoras, correcciones o módulos nuevos.

🧑‍💻 Créditos
Creado por José Gajardo
Desarrollo y mantenimiento: HomeMediaForge
Licencia: MIT
