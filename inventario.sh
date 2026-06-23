#!/bin/bash
# inventario.sh — Recopilación de inventario del sistema
# Uso: ./inventario.sh
# Genera reporte completo de hardware y software del sistema

# 1. INICIALIZACIÓN Y VALIDACIONES
CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: No se encontró config.txt"
    exit 1
fi

source "$CONFIG_FILE"
validar_config || exit 1

# 2. CREAR DIRECTORIOS DE TRABAJO
mkdir -p "$LOG_DIR" "$INVENTORY_DIR" 2>/dev/null || {
    echo "Error: No se pudieron crear los directorios de reportes"
    exit 1
}

# 3. VARIABLES DE TRABAJO
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TIMESTAMP_FORMATO=$(date +"${TIMESTAMP_FORMAT}")
ARCHIVO_INVENTARIO="${INVENTORY_DIR}/inventario_${TIMESTAMP}.txt"

# 4. TRAP PARA MANEJO DE SEÑALES
trap 'echo "Inventario interrumpido"; exit 1' SIGINT SIGTERM

# ============================================================================
# FUNCIONES
# ============================================================================

# 5. Obtener información de CPU
obtener_info_cpu() {
    echo "═══ INFORMACIÓN DE PROCESADOR ═══"

    # Modelo de CPU
    if [ -f /proc/cpuinfo ]; then
        echo "Modelo: $(grep -m 1 'model name' /proc/cpuinfo | cut -d':' -f2 | xargs)"
    else
        echo "Modelo: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Desconocido')"
    fi

    # Número de núcleos
    local nucleos=$(nproc 2>/dev/null || grep -c "processor" /proc/cpuinfo 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "1")
    echo "Núcleos: $nucleos"

    # Velocidad de CPU
    if [ -f /proc/cpuinfo ]; then
        local velocidad=$(grep -m 1 'cpu MHz' /proc/cpuinfo | cut -d':' -f2 | xargs)
        [ -n "$velocidad" ] && echo "Velocidad: ${velocidad} MHz"
    fi

    echo ""
}

# 6. Obtener información de memoria
obtener_info_memoria() {
    echo "═══ INFORMACIÓN DE MEMORIA ═══"

    local total=$(free -m 2>/dev/null | awk 'NR==2 {print $2}' || sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f", $1/1024/1024}')
    local usada=$(free -m 2>/dev/null | awk 'NR==2 {print $3}' || echo "0")
    local disponible=$(free -m 2>/dev/null | awk 'NR==2 {print $7}' || echo "$total")
    local porcentaje=$(awk "BEGIN {printf \"%.1f\", ($usada/$total)*100}" 2>/dev/null || echo "0")

    echo "Total: ${total} MB ($(awk "BEGIN {printf \"%.2f\", $total/1024}" 2>/dev/null || echo "0") GB)"
    echo "Usada: ${usada} MB"
    echo "Disponible: ${disponible} MB"
    echo "Porcentaje usado: ${porcentaje}%"

    echo ""
}

# 7. Obtener información de almacenamiento
obtener_info_almacenamiento() {
    echo "═══ INFORMACIÓN DE ALMACENAMIENTO ═══"

    df -h | while IFS= read -r linea; do
        echo "$linea"
    done

    echo ""
}

# 8. Obtener información del sistema operativo
obtener_info_sistema() {
    echo "═══ INFORMACIÓN DEL SISTEMA OPERATIVO ═══"

    # Nombre del SO
    if [ -f /etc/os-release ]; then
        echo "SO: $(grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')"
        echo "Versión: $(grep '^VERSION=' /etc/os-release | cut -d'=' -f2 | tr -d '"')"
    elif [ -f /etc/lsb-release ]; then
        echo "SO: $(grep 'DISTRIB_DESCRIPTION' /etc/lsb-release | cut -d'=' -f2 | tr -d '"')"
    else
        echo "SO: $(sw_vers -productName 2>/dev/null || echo 'Desconocido')"
    fi

    # Kernel
    echo "Kernel: $(uname -r)"

    # Hostname
    echo "Hostname: $(hostname)"

    # Uptime
    echo "Uptime: $(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*$//')"

    echo ""
}

# 9. Obtener información de dispositivos
obtener_info_dispositivos() {
    echo "═══ INFORMACIÓN DE DISPOSITIVOS ═══"

    # Interfaces de red
    echo "Interfaces de red:"
    if command -v ip &>/dev/null; then
        ip -o link show | awk -F': ' '{print "  - " $2}' | head -10
    else
        ifconfig 2>/dev/null | grep "^[a-z]" | awk '{print "  - " $1}' | head -10
    fi

    echo ""

    # Unidades de almacenamiento
    echo "Unidades de almacenamiento:"
    if [ -f /proc/partitions ]; then
        awk 'NR>2 {print "  - " $4 " (" $3 " KB)"}' /proc/partitions | head -10
    fi

    echo ""
}

# 10. Obtener información de servicios
obtener_info_servicios() {
    echo "═══ SERVICIOS ACTIVOS ═══"

    if command -v systemctl &>/dev/null; then
        echo "Servicios activos (systemd):"
        systemctl list-units --type=service --state=running 2>/dev/null | \
            grep -v '^UNIT' | \
            grep -v '^$' | \
            awk '{print "  - " $1}' | \
            head -15
    fi

    echo ""
}

# 11. Obtener información de usuarios
obtener_info_usuarios() {
    echo "═══ USUARIOS DEL SISTEMA ═══"

    echo "Usuarios con shell de login (UID >= 1000):"
    awk -F: '$3 >= 1000 && $3 < 65534 {print "  - " $1 " (UID: " $3 ", Shell: " $7 ")"}' /etc/passwd

    echo ""
}

# 12. Generar reporte de texto plano
generar_reporte_texto() {
    local archivo="$1"

    {
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║        INVENTARIO DEL SISTEMA - $(date +%Y-%m-%d' '%H:%M:%S)           ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""

        obtener_info_sistema
        obtener_info_cpu
        obtener_info_memoria
        obtener_info_almacenamiento
        obtener_info_dispositivos
        obtener_info_servicios
        obtener_info_usuarios

        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║ Reporte generado: $TIMESTAMP_FORMATO"
        echo "║ Por: $(whoami)"
        echo "║ Desde: $(hostname)"
        echo "╚════════════════════════════════════════════════════════════╝"
    } > "$archivo"
}

# 13. Generar reporte JSON
generar_reporte_json() {
    local archivo="$1"

    {
        echo "{"
        echo "  \"timestamp\": \"$TIMESTAMP_FORMATO\","
        echo "  \"hostname\": \"$(hostname)\","
        echo "  \"sistema\": {"

        # Sistema
        if [ -f /etc/os-release ]; then
            echo "    \"so\": \"$(grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')\","
        fi
        echo "    \"kernel\": \"$(uname -r)\","
        echo "    \"uptime\": \"$(uptime -p 2>/dev/null || echo 'N/A')\""

        echo "  },"
        echo "  \"hardware\": {"

        # CPU
        local nucleos=$(nproc 2>/dev/null || echo "1")
        echo "    \"nucleos_cpu\": $nucleos,"

        # Memoria
        local memoria_total=$(free -m 2>/dev/null | awk 'NR==2 {print $2}' || echo "0")
        echo "    \"memoria_total_mb\": $memoria_total"

        echo "  }"
        echo "}"
    } > "$archivo"
}

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================

echo "╔════════════════════════════════════════╗"
echo "║   GENERADOR DE INVENTARIO DEL SISTEMA   ║"
echo "╚════════════════════════════════════════╝"
echo ""

registrar "inventario.sh" "INICIO: Generando inventario del sistema"

# Generar reporte de texto
echo "[*] Generando reporte de texto..."
generar_reporte_texto "$ARCHIVO_INVENTARIO"

if [ -f "$ARCHIVO_INVENTARIO" ]; then
    echo "✓ Reporte de texto generado: $ARCHIVO_INVENTARIO"

    # Mostrar preview
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    head -40 "$ARCHIVO_INVENTARIO"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    registrar "inventario.sh" "COMPLETADO: Reporte de inventario generado - $ARCHIVO_INVENTARIO"

    # Enviar notificación por Telegram
    CPU_COUNT=$(nproc 2>/dev/null || echo "N/A")
    MEMORIA_TOTAL=$(free -m 2>/dev/null | awk 'NR==2 {printf "%.0f MB", $2}' || echo "N/A")
    USO_DISCO=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo "N/A")

    MSG="📋 INVENTARIO GENERADO 📋

Hostname: $(hostname)
CPU: $CPU_COUNT núcleos
Memoria: $MEMORIA_TOTAL
Uso Disco: $USO_DISCO

Reporte: $ARCHIVO_INVENTARIO"

    enviar_telegram "Inventario del Sistema" "$MSG" || true

    exit 0
else
    echo "✗ Error al generar reporte"
    registrar "inventario.sh" "ERROR: No se pudo generar el reporte de inventario"
    exit 1
fi

