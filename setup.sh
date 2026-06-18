#!/bin/bash
# este script instala el proyecto
# si se ejecuta normal instala en carpetas del usuario
# si se ejecuta con root instala en /opt y /etc

# se guardan las rutas principales
ruta="$(cd "$(dirname "$0")" && pwd)"
archivo="${OS_RELEASE_FILE:-/etc/os-release}"
modo="no"

# se valida si el usuario solo quiere comprobar el sistema
if [ "${1:-}" = "--check" ]; then
    modo="si"
elif [ "$#" -gt 0 ]; then
    echo "Uso: $0 [--check]"
    exit 1
fi

# si se interrumpe la instalacion se sale de forma limpia
trap 'echo "instalacion interrumpida"; exit 1' SIGINT SIGTERM

# se valida que exista el archivo del sistema operativo
if [ ! -f "$archivo" ]; then
    echo "Error: no se pudo identificar el sistema operativo."
    exit 1
fi

# se carga informacion del sistema
source "$archivo"

# se valida que sea un sistema basado en ubuntu o debian
if [ "$ID" != "zorin" ] && [[ "${ID_LIKE:-}" != *"ubuntu"* ]] && [[ "${ID_LIKE:-}" != *"debian"* ]]; then
    echo "Error: este instalador esta preparado para Zorin Ubuntu o Debian."
    echo "Sistema detectado: ${PRETTY_NAME:-desconocido}"
    exit 1
fi

echo "instalador del sistema de servicios"
echo "sistema detectado: ${PRETTY_NAME:-desconocido}"

# se revisan dependencias principales
dependencias="bash awk sed tar find df free ps curl ssh scp timeout"
faltantes=""

for comando in $dependencias
do
    if ! command -v "$comando" > /dev/null 2>&1; then
        faltantes="$faltantes $comando"
    fi
done

if [ -n "$faltantes" ]; then
    echo "Error: faltan dependencias:$faltantes"
    echo "Puedes instalarlas con apt."
    exit 1
fi

# si solo era revision se termina aqui
if [ "$modo" = "si" ]; then
    echo "sistema compatible y dependencias disponibles"
    exit 0
fi

# si es root se usan rutas del sistema
# si no es root se usan rutas del usuario para trabajar sin permisos especiales
if [ "$(id -u)" -eq 0 ]; then
    carpeta="/opt/sistema-servicios"
    carpeta_config="/etc/sistema-servicios"
    carpeta_logs="/var/log/sistema-servicios"
    carpeta_reportes="/var/log/reportes"
    carpeta_respaldos="/var/backups/sistema-servicios"
else
    carpeta="$HOME/.local/share/sistema-servicios"
    carpeta_config="$HOME/.config/sistema-servicios"
    carpeta_logs="$HOME/.local/state/sistema-servicios/logs"
    carpeta_reportes="$HOME/.local/state/sistema-servicios/reportes"
    carpeta_respaldos="$HOME/respaldos/sistema-servicios"
fi

# se crean carpetas principales
mkdir -p "$carpeta"
mkdir -p "$carpeta_config"
mkdir -p "$carpeta_logs"
mkdir -p "$carpeta_reportes"
mkdir -p "$carpeta_respaldos"

if [ "$?" -ne 0 ]; then
    echo "Error: no se pudieron crear las carpetas del proyecto."
    exit 1
fi

# se copian los scripts del proyecto
for archivo in usuarios.sh respaldo.sh monitoreo.sh servicios.sh remoto.sh red.sh inventario.sh diagnostico.sh configurar-telegram.sh config.txt hosts.txt crontab.txt
do
    if [ -f "$ruta/$archivo" ]; then
        cp "$ruta/$archivo" "$carpeta/"
    fi
done

# se crea archivo de credenciales desactivado si no existe
if [ ! -f "$carpeta_config/telegram.env" ]; then
    {
        echo "TELEGRAM_ENABLED=false"
        echo "TELEGRAM_BOT_TOKEN=''"
        echo "TELEGRAM_CHAT_ID=''"
    } > "$carpeta_config/telegram.env"
fi

# se asignan permisos normales
chmod 755 "$carpeta" "$carpeta"/*.sh
chmod 700 "$carpeta_config"
chmod 600 "$carpeta_config/telegram.env"

# si se ejecuto como root se ajusta dueño del sistema
if [ "$(id -u)" -eq 0 ]; then
    chown -R root:root "$carpeta" "$carpeta_config"
fi

echo "instalacion finalizada correctamente"
echo "scripts instalados en: $carpeta"
echo "configuracion en: $carpeta_config"
echo "logs en: $carpeta_logs"
echo "respaldos en: $carpeta_respaldos"
