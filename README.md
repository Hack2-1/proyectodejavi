# Sistema Automatizado de Gestión de Servicios con Bash

Proyecto modular para administrar y supervisar Zorin OS Pro y otros sistemas
GNU/Linux basados en Ubuntu mediante scripts Bash. Centraliza configuración,
logs, reportes y notificaciones opcionales por Telegram.

## Módulos

| Script | Función |
| --- | --- |
| `usuarios.sh` | Crear, modificar, listar y eliminar usuarios. |
| `respaldo.sh` | Crear respaldos comprimidos y verificar su integridad. |
| `monitoreo.sh` | Medir CPU, memoria y disco con umbrales configurables. |
| `servicios.sh` | Verificar servicios e intentar reiniciarlos. |
| `remoto.sh` | Copiar y ejecutar scripts en hosts mediante SSH. |
| `diagnostico.sh` | Recopilar datos básicos en una prueba remota. |
| `red.sh` | Revisar conectividad y puertos críticos. |
| `inventario.sh` | Generar un inventario de hardware y software. |

## Requisitos

- GNU/Linux con Bash 4 o superior.
- Comandos base: `awk`, `sed`, `tar`, `find`, `df`, `free` y `ps`.
- `curl` para notificaciones por Telegram.
- `ping`, `nc` o `nmap` para las pruebas de red.
- `ssh`, `scp` y `timeout` para la ejecución remota.
- Permisos de administrador para `usuarios.sh` y para reiniciar servicios.

En Zorin OS Pro:

```bash
sudo apt update
sudo apt install bash curl openssh-client tar gzip bzip2 xz-utils iputils-ping netcat-openbsd
```

## Configuración

Edita `config.txt` para ajustar rutas, umbrales, servicios, hosts y respaldos.
Las credenciales de Telegram se cargan desde
`/etc/sistema-servicios/telegram.env`, fuera del repositorio.

```bash
sudo ./configurar-telegram.sh
```

El configurador oculta el token, valida el bot y envía un mensaje de prueba.
También es posible usar variables de entorno para una ejecución puntual:

```bash
export TELEGRAM_ENABLED=true
export TELEGRAM_BOT_TOKEN="token_del_bot"
export TELEGRAM_CHAT_ID="id_del_chat"
./monitoreo.sh
```

Nunca guardes ni publiques tokens reales en el repositorio o en capturas.

## Pruebas locales

Las pruebas usan directorios temporales y no crean usuarios, no reinician
servicios y no se conectan a hosts remotos:

```bash
chmod +x ./*.sh
./test.sh
```

## Instalación

```bash
./setup.sh --check
sudo ./setup.sh
```

`--check` valida Zorin OS y las dependencias sin modificar el sistema. La
instalación copia el proyecto a `/opt/sistema-servicios`, crea el grupo
`sistema-servicios` y prepara:

- `/var/log/sistema-servicios`
- `/var/log/reportes`
- `/var/backups/sistema-servicios`

Después de instalar:

```bash
sudo nano /opt/sistema-servicios/config.txt
sudo /opt/sistema-servicios/configurar-telegram.sh
/opt/sistema-servicios/monitoreo.sh
```

## Uso

```bash
# Monitoreo con umbrales personalizados
./monitoreo.sh -c 80 -d 85 -m 90

# Respaldo de directorios específicos
./respaldo.sh /home/usuario/documentos /etc

# Supervisión de servicios
sudo ./servicios.sh nginx ssh

# Monitoreo de red
./red.sh -f hosts.txt -p "22 80 443"

# Inventario del equipo
./inventario.sh

# Ejecución remota
./remoto.sh ./diagnostico.sh hosts.txt

# Gestión interactiva de usuarios
sudo ./usuarios.sh
```

La creación de usuarios exige nombres válidos, contraseña de al menos ocho
caracteres y confirmación. La ejecución remota utiliza autenticación SSH por
llave y envía un resumen a Telegram.

## Automatización

`crontab.txt` contiene ejemplos para respaldos, monitoreo, servicios, red e
inventarios. Revisa las rutas antes de copiarlas con `crontab -e`.

El documento `MANUAL_TECNICO.pdf` contiene la instalación, configuración,
estructura de módulos, casos de prueba y guía para la demostración final.
`PRESENTACION_FINAL.pdf` sirve como apoyo para la exposición del equipo.

## Estructura

```text
.
├── config.txt
├── setup.sh
├── configurar-telegram.sh
├── test.sh
├── usuarios.sh
├── respaldo.sh
├── monitoreo.sh
├── servicios.sh
├── remoto.sh
├── diagnostico.sh
├── red.sh
├── inventario.sh
├── hosts.txt
├── crontab.txt
├── MANUAL_TECNICO.pdf
└── PRESENTACION_FINAL.pdf
```

## Seguridad

- Ejecuta cada módulo con los permisos mínimos necesarios.
- Mantén `/etc/sistema-servicios/telegram.env` con permisos restrictivos.
- Usa autenticación por llaves para SSH.
- Revisa `hosts.txt` antes de una ejecución remota.
- Conserva Telegram deshabilitado mientras no esté configurado.

## Licencia

Consulta `LICENSE`.
