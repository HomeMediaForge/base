# 🔐 HomeMediaForge – Módulo `step-ca`

Autoridad certificadora interna basada en [`smallstep/step-ca`](https://github.com/smallstep/certificates) que emite certificados ACME para Traefik y servicios locales.

---

## 📦 Objetivo

- Proveer una CA privada que firme certificados para `*.local`, `*.homemediaforge.local` y otros dominios internos.
- Automatizar la emisión y renovación vía ACME para Traefik (resolver `hmf`).
- Distribuir el certificado raíz a clientes (Windows, macOS, Linux) sin intervención manual posterior.

---

## 🗂️ Estructura

```
${STACK_CONFIG_DIR}/step-ca/
├── config/ca.json          # Configuración step-ca (policy incluida)
├── certs/
│   ├── root_ca.crt         # Certificado raíz (instálalo en los clientes)
│   └── intermediate_ca.crt # (creado por step-ca)
├── secrets/
│   ├── password.txt        # Password del servicio
│   └── provisioner_password.txt
└── db/                     # Base de datos (detalles de certificados emitidos)
```

---

## ⚙️ Variables (`env.template`)

| Variable | Descripción | Valor por defecto |
| --- | --- | --- |
| `STEP_CA_VERSION` | Versión de la imagen `smallstep/step-ca` | `0.28.0` |
| `STEP_CA_LISTEN_ADDR` | Dirección/puerto donde escucha la CA | `0.0.0.0:9000` |
| `STEP_CA_URL` | URL base utilizada por clientes | `https://127.0.0.1:9000` |
| `STEP_CA_ACME_PROVISIONER` | Nombre del provisioner ACME | `hmf-acme` |
| `STEP_CA_ACME_EMAIL` | Email del contacto ACME | `admin@homemediaforge.local` |
| `STEP_CA_ACME_DIRECTORY` | Endpoint ACME para Traefik | `https://127.0.0.1:9000/acme/hmf-acme/directory` |
| `STEP_CA_ALLOWED_SANS` | Lista separada por comas de SAN permitidos | `*.local,*.homemediaforge.local,homemediaforge.local,local` |
| `STEP_CA_NAME` | Nombre de la CA | `HomeMediaForge Internal CA` |
| `STEP_CA_DNS` | Hostnames del servicio CA | `ca.local` |

---

## 🚀 Puesta en marcha

1. **Inicializar la CA (una sola vez)**
   ```bash
   ./scripts/bootstrap-step-ca.sh
   ```
   - Genera contraseñas, ejecuta `step ca init` y actualiza la política `allow.dns` según `STEP_CA_ALLOWED_SANS`.
   - Si ya existe, el script mantiene la configuración y sólo refuerza la política.

2. **Preparar Traefik**
   ```bash
   touch config/traefik/acme.json
   chmod 600 config/traefik/acme.json
   ```

3. **Arrancar servicios**
   ```bash
   docker compose \
     -f modules/admin/core.network.yml \
     -f modules/admin/step-ca.yml up -d
   ```
   Traefik usará el resolver `hmf` para emitir certificados y los almacenará en `config/traefik/acme.json`.

4. **Confiar en la CA**
   - Copia `config/step-ca/certs/root_ca.crt` a cada cliente.
   - Windows (administrador):
     ```powershell
     Import-Certificate -FilePath C:\ruta\root_ca.crt -CertStoreLocation Cert:\LocalMachine\Root
     ```
   - Linux:
     ```bash
     sudo cp root_ca.crt /usr/local/share/ca-certificates/hmf-root.crt
     sudo update-ca-certificates
     ```
   - macOS: doble clic → “Añadir” → establece confianza “Siempre confiar”.

5. **Verificar**
   ```bash
   openssl s_client -connect 127.0.0.1:443 -servername radarr.local -showcerts
   ```
   Debe mostrar la cadena firmada por “HomeMediaForge Internal CA”.

---

## 🔄 Renovaciones

- Traefik renueva certificados automáticamente antes de expirar (gestiona ACME y almacena tokens en `acme.json`).
- `step-ca` mantiene el historial en `db/`. Para revocar un certificado:
  ```bash
  docker exec stepca step ca revoke --cert <serial> \
    --reason superseded \
    --password-file /home/step/secrets/password.txt
  ```

---

## 🔧 Mantenimiento

- **Respaldo**: guarda `config/`, `certs/`, `secrets/` y `db/`. Sin `password.txt` y `authority.key` no podrás reanudar la CA.
- **Cambiar dominios permitidos**: ajusta `STEP_CA_ALLOWED_SANS` en `.env`, vuelve a ejecutar `bootstrap-step-ca.sh` y reinicia el contenedor.
- **Actualización de versión**: cambia `STEP_CA_VERSION`, reinicia `step-ca` (`docker compose ... up -d stepca`).
- **Seguridad**: restringe acceso a `STEP_CA_PORT` únicamente desde los hosts que necesiten emitir (Traefik, servicios internos). No expongas la CA a Internet sin autenticación adicional.

---

## 🤝 Integraciones

- **Traefik**: cada servicio detrás de Traefik declara `traefik.http.routers.<name>.tls.certresolver=hmf`.
- **Otros servicios/MTLS**: usa el CLI `step` con el mismo provisioner ACME o crea provisioners adicionales (JWK, OIDC) en `ca.json`.

---

## 📚 Referencias

- [smallstep – certificates](https://github.com/smallstep/certificates)
- [Traefik – ACME](https://doc.traefik.io/traefik/https/acme/)
- [Documentación general HomeMediaForge](./core.network.md)
