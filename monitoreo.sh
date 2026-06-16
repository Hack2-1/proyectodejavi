#!/bin/bash
# monitoreo.sh — Monitoreo de recursos del sistema
# Uso: ./monitoreo.sh [-c UMBRAL_CPU] [-d UMBRAL_DISCO]
# Monitorea CPU y espacio en disco, alerta si se superan umbrales

# 1. INICIALIZACIÓN Y VALIDACIONES
CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: No se encontró config.txt"
    exit 1
fi

source "$CONFIG_FILE"
validar_config || exit 1

# 2. CREAR DIRECTORIO DE LOGS
mkdir -p "$LOG_DIR" 2>/dev/null || {
    echo "Error: No se pudo crear el directorio de logs: $LOG_DIR"
    exit 1
}

# 3. VARIABLES DE TRABAJO
UMBRAL_CPU_FINAL="${UMBRAL_CPU}"
UMBRAL_DISCO_FINAL="${UMBRAL_DISCO}"
UMBRAL_MEMORIA_FINAL="${UMBRAL_MEMORIA}"

# 4. TRAP PARA MANEJO DE SEÑALES
trap 'echo "Monitoreo interrumpido"; exit 1' SIGINT SIGTERM

# ============================================================================
# FUNCIONES
# ============================================================================

# 5. Parsear argumentos de línea de comandos
parsear_argumentos() {
    while getopts "c:d:m:h" opt; do
        case "$opt" in
            c)
                if ! [[ "$OPTARG" =~ ^[0-9]+$ ]] || [ "$OPTARG" -lt 0 ] || [ "$OPTARG" -gt 100 ]; then
                    echo "Error: Umbral de CPU debe estar entre 0 y 100"
                    exit 1
                fi
                UMBRAL_CPU_FINAL="$OPTARG"
                ;;
            d)
                if ! [[ "$OPTARG" =~ ^[0-9]+$ ]] || [ "$OPTARG" -lt 0 ] || [ "$OPTARG" -gt 100 ]; then
                    echo "Error: Umbral de disco debe estar entre 0 y 100"
                    exit 1
                fi
                UMBRAL_DISCO_FINAL="$OPTARG"
                ;;
            m)
                if ! [[ "$OPTARG" =~ ^[0-9]+$ ]] || [ "$OPTARG" -lt 0 ] || [ "$OPTARG" -gt 100 ]; then
                    echo "Error: Umbral de memoria debe estar entre 0 y 100"
                    exit 1
                fi
                UMBRAL_MEMORIA_FINAL="$OPTARG"
                ;;
            h)
                echo "Uso: $0 [-c UMBRAL_CPU] [-d UMBRAL_DISCO] [-m UMBRAL_MEMORIA]"
                echo "  -c: Umbral de CPU en porcentaje (0-100, default: $UMBRAL_CPU)"
                echo "  -d: Umbral de disco en porcentaje (0-100, default: $UMBRAL_DISCO)"
                echo "  -m: Umbral de memoria en porcentaje (0-100, default: $UMBRAL_MEMORIA)"
                exit 0
                ;;
            *)
                echo "Opción no válida: -$OPTARG"
                exit 1
                ;;
        esac
    done
}

# 6. Obtener porcentaje de uso de CPU
obtener_cpu() {
    # Usar top (compatible con Linux y macOS)
    local cpu
    cpu=$(top -bn1 2>/dev/null | awk '/Cpu\(s\)/ {for (i=1; i<=NF; i++) if ($i ~ /id/) {gsub(/,/, "", $(i-1)); printf "%.1f", 100-$(i-1); exit}}')

    # Alternativa si top falla
    if [ -z "$cpu" ]; then
        cpu=$(ps aux | awk 'NR>1 {sum+=$3} END {printf "%.1f", sum}')
    fi

    echo "$cpu"
}

# 7. Obtener porcentaje de uso de disco
obtener_disco() {
    local disco
    disco=$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
    echo "$disco"
}

# 8. Obtener información de memoria
obtener_memoria() {
    local memoria_total
    local memoria_disponible
    local porcentaje

    memoria_total=$(free -m | awk 'NR==2 {print $2}')
    memoria_disponible=$(free -m | awk 'NR==2 {print $7}')
    porcentaje=$(awk -v total="$memoria_total" -v disponible="$memoria_disponible" \
        'BEGIN {if (total > 0) printf "%.1f", ((total-disponible)/total)*100; else print "0.0"}')

    echo "$porcentaje"
}

# 9. Generar reporte de monitoreo
generar_reporte() {
    local cpu="$1"
    local disco="$2"
    local memoria="$3"

    local estado="✓ NORMAL"
    local alertas=""

    # Validar CPU
    if awk -v valor="$cpu" -v umbral="$UMBRAL_CPU_FINAL" 'BEGIN {exit !(valor > umbral)}'; then
        estado="⚠ ALERTA"
        alertas="${alertas}⚠ CPU: ${cpu}% (Umbral: ${UMBRAL_CPU_FINAL}%)\n"
    fi

    # Validar DISCO
    if awk -v valor="$disco" -v umbral="$UMBRAL_DISCO_FINAL" 'BEGIN {exit !(valor > umbral)}'; then
        estado="⚠ ALERTA"
        alertas="${alertas}⚠ DISCO: ${disco}% (Umbral: ${UMBRAL_DISCO_FINAL}%)\n"
    fi

    # Validar MEMORIA
    if awk -v valor="$memoria" -v umbral="$UMBRAL_MEMORIA_FINAL" 'BEGIN {exit !(valor > umbral)}'; then
        estado="⚠ ALERTA"
        alertas="${alertas}⚠ MEMORIA: ${memoria}% (Umbral: ${UMBRAL_MEMORIA_FINAL}%)\n"
    fi

    echo "$estado"
    printf "%b" "$alertas"
}

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================

parsear_argumentos "$@"

echo "╔════════════════════════════════════════╗"
echo "║    MONITOREO DE RECURSOS DEL SISTEMA    ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📊 Umbrales configurados:"
echo "   CPU: ${UMBRAL_CPU_FINAL}%"
echo "   DISCO: ${UMBRAL_DISCO_FINAL}%"
echo "   MEMORIA: ${UMBRAL_MEMORIA_FINAL}%"
echo ""

registrar "monitoreo.sh" "INICIO: Monitoreo iniciado - Umbrales: CPU=${UMBRAL_CPU_FINAL}%, DISCO=${UMBRAL_DISCO_FINAL}%, MEMORIA=${UMBRAL_MEMORIA_FINAL}%"

# Obtener valores actuales
echo "[*] Leyendo datos del sistema..."
CPU=$(obtener_cpu)
DISCO=$(obtener_disco)
MEMORIA=$(obtener_memoria)

# Mostrar estado actual
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "CPU:     %6.1f%%\n" "$CPU"
printf "DISCO:   %6.1f%%\n" "$DISCO"
printf "MEMORIA: %6.1f%%\n" "$MEMORIA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Registrar en log
registrar "monitoreo.sh" "LECTURA: CPU=${CPU}%, DISCO=${DISCO}%, MEMORIA=${MEMORIA}%"

# Generar reporte y verificar alertas
REPORTE=$(generar_reporte "$CPU" "$DISCO" "$MEMORIA")
ESTADO=$(echo "$REPORTE" | head -n1)
ALERTAS=$(echo "$REPORTE" | tail -n +2)

echo "Estado: $ESTADO"
echo ""

# Si hay alertas, enviar notificación por Telegram
if [[ "$ESTADO" == "⚠ ALERTA" ]]; then
    echo "⚠ Se detectaron problemas:"
    echo -e "$ALERTAS"

    # Enviar alerta por Telegram
    MSG="🚨 ALERTA DE RECURSOS 🚨
CPU: ${CPU}%
DISCO: ${DISCO}%
MEMORIA: ${MEMORIA}%

Umbrales:
CPU: ${UMBRAL_CPU_FINAL}%
DISCO: ${UMBRAL_DISCO_FINAL}%
MEMORIA: ${UMBRAL_MEMORIA_FINAL}%"

    enviar_telegram "Alerta de Recursos" "$MSG" || true
    registrar "monitoreo.sh" "ALERTA: Recurso excede umbral - $ALERTAS"
fi

exit 0
