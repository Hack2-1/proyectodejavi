#!/bin/bash
# setup.sh — Script de instalación y configuración
# Uso: sudo ./setup.sh
# Instala el sistema de gestión de servicios en Zorin OS/Ubuntu

# 1. VARIABLES Y VALIDACIONES
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/sistema-servicios"
CONFIG_DIR="/etc/sistema-servicios"
GRUPO_SISTEMA="sistema-servicios"
USUARIO_REAL="${SUDO_USER:-$(id -un)}"
OS_RELEASE_FILE="${OS_RELEASE_FILE:-/etc/os-release}"
MODO_VERIFICACION=false

if [ "${1:-}" = "--check" ]; then
    MODO_VERIFICACION=true
elif [ $# -gt 0 ]; then
    echo "Uso: sudo ./setup.sh [--check]"
    exit 1
fi

if [ "$MODO_VERIFICACION" != "true" ] && [ "$(id -u)" -ne 0 ]; then
    echo "Error: Este script debe ejecutarse como root (usar: sudo ./setup.sh)"
    exit 1
fi

if [ ! -f "$OS_RELEASE_FILE" ]; then
    echo "Error: No se pudo identificar el sistema operativo"
    exit 1
fi

source "$OS_RELEASE_FILE"

if [ "$ID" != "zorin" ] && [[ "${ID_LIKE:-}" != *"ubuntu"* ]] &&
   [[ "${ID_LIKE:-}" != *"debian"* ]]; then
    echo "Error: Este instalador está preparado para Zorin OS, Ubuntu o Debian"
    echo "Sistema detectado: ${PRETTY_NAME:-desconocido}"
    exit 1
fi

echo "╔════════════════════════════════════════╗"
echo "║   INSTALACIÓN DEL SISTEMA DE GESTIÓN    ║"
echo "║        ZORIN OS / GNU-LINUX              ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Sistema detectado: ${PRETTY_NAME}"
echo ""

# 2. VALIDAR DEPENDENCIAS
DEPENDENCIAS=(bash awk sed tar find df free ps curl ping ssh scp timeout systemctl)
DEPENDENCIAS_FALTANTES=()

for comando in "${DEPENDENCIAS[@]}"; do
    command -v "$comando" &>/dev/null || DEPENDENCIAS_FALTANTES+=("$comando")
done

if [ "${#DEPENDENCIAS_FALTANTES[@]}" -gt 0 ]; then
    echo "Error: Faltan dependencias: ${DEPENDENCIAS_FALTANTES[*]}"
    echo "Instala los paquetes requeridos con:"
    echo "  sudo apt update"
    echo "  sudo apt install curl openssh-client tar gzip bzip2 xz-utils iputils-ping netcat-openbsd"
    exit 1
fi

if [ "$MODO_VERIFICACION" = "true" ]; then
    echo "✓ Sistema compatible: ${PRETTY_NAME}"
    echo "✓ Dependencias principales disponibles"
    exit 0
fi

# 3. CREAR GRUPO Y DIRECTORIOS
if ! getent group "$GRUPO_SISTEMA" >/dev/null; then
    groupadd "$GRUPO_SISTEMA"
fi

if [ "$USUARIO_REAL" != "root" ]; then
    usermod -aG "$GRUPO_SISTEMA" "$USUARIO_REAL"
fi

echo "[*] Creando directorios..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p /var/log/sistema-servicios
mkdir -p /var/backups/sistema-servicios
mkdir -p /var/log/reportes

echo "✓ Directorios creados"

# 4. COPIAR ARCHIVOS
echo "[*] Copiando scripts..."
cp -v "$SCRIPT_DIR"/usuarios.sh "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/respaldo.sh "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/monitoreo.sh "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/servicios.sh "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/remoto.sh "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/red.sh "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/inventario.sh "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/diagnostico.sh "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/configurar-telegram.sh "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/config.txt "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/hosts.txt "$INSTALL_DIR/"
cp -v "$SCRIPT_DIR"/crontab.txt "$INSTALL_DIR/"

echo "✓ Scripts copiados"

# 5. CONFIGURAR CREDENCIALES EXTERNAS
if [ ! -f "${CONFIG_DIR}/telegram.env" ]; then
    {
        echo 'TELEGRAM_ENABLED=false'
        echo 'TELEGRAM_BOT_TOKEN=""'
        echo 'TELEGRAM_CHAT_ID=""'
    } > "${CONFIG_DIR}/telegram.env"
fi

# 6. ESTABLECER PERMISOS
echo "[*] Estableciendo permisos..."
chown -R root:"$GRUPO_SISTEMA" "$INSTALL_DIR"
chown -R root:"$GRUPO_SISTEMA" /var/log/sistema-servicios /var/log/reportes
chmod 755 "$INSTALL_DIR" "$INSTALL_DIR"/*.sh
chmod 640 "$INSTALL_DIR"/config.txt "$INSTALL_DIR"/hosts.txt "$INSTALL_DIR"/crontab.txt
chmod 2775 /var/log/sistema-servicios /var/log/reportes
find /var/log/sistema-servicios /var/log/reportes -type d -exec chmod 2775 {} \;
find /var/log/sistema-servicios /var/log/reportes -type f -exec chmod 664 {} \;
chown root:"$GRUPO_SISTEMA" "$CONFIG_DIR"
chmod 750 "$CONFIG_DIR"
chmod 640 "${CONFIG_DIR}/telegram.env"
chown root:"$GRUPO_SISTEMA" "${CONFIG_DIR}/telegram.env"

echo "✓ Permisos establecidos"

# 7. CREAR USUARIO PARA RESPALDOS
echo "[*] Configurando usuario para respaldos..."
if ! id "backup" &>/dev/null; then
    useradd -m -s /bin/bash backup
    echo "✓ Usuario 'backup' creado"
else
    echo "✓ Usuario 'backup' ya existe"
fi

# Dar permisos necesarios al usuario backup sin convertirlo en root
usermod -aG "$GRUPO_SISTEMA" backup
chown -R backup:"$GRUPO_SISTEMA" /var/backups/sistema-servicios
chmod 2770 /var/backups/sistema-servicios

# 8. VERIFICACIÓN FINAL
echo ""
echo "╔════════════════════════════════════════╗"
echo "║        VERIFICACIÓN DE INSTALACIÓN      ║"
echo "╚════════════════════════════════════════╝"
echo ""

echo "Scripts instalados:"
ls -lh "$INSTALL_DIR"/*.sh | awk '{print "  ✓ " $9}'

echo ""
echo "Directorios de logs:"
ls -ld /var/log/sistema-servicios 2>/dev/null && echo "  ✓ /var/log/sistema-servicios" || echo "  ✗ /var/log/sistema-servicios"
ls -ld /var/log/reportes 2>/dev/null && echo "  ✓ /var/log/reportes" || echo "  ✗ /var/log/reportes"

echo ""
echo "Directorios de respaldos:"
ls -ld /var/backups/sistema-servicios 2>/dev/null && echo "  ✓ /var/backups/sistema-servicios" || echo "  ✗ /var/backups/sistema-servicios"

echo ""
echo "╔════════════════════════════════════════╗"
echo "║      INSTALACIÓN COMPLETADA ✓           ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Próximos pasos:"
echo "  1. Cierra sesión y vuelve a entrar para aplicar el grupo $GRUPO_SISTEMA"
echo "  2. Edita $INSTALL_DIR/config.txt con tus parámetros"
echo "  3. Configura Telegram: sudo $INSTALL_DIR/configurar-telegram.sh"
echo "  4. Ejecuta las pruebas desde el repositorio: ./test.sh"
echo ""
