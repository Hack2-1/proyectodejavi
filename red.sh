#!/bin/bash
# red.sh — Monitoreo de conectividad y puertos de la red
# Uso: ./red.sh [-f archivo_hosts] [-p puertos]
# Verifica ping y puertos abiertos, clasifica hosts como accesibles/parciales/sin respuesta

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
HOSTS_A_VERIFICAR="$HOSTS_PING"
PUERTOS_A_VERIFICAR="$PUERTOS_CRITICOS"

# 4. TRAP PARA MANEJO DE SEÑALES
trap 'echo "Monitoreo de red interrumpido"; exit 1' SIGINT SIGTERM

# ============================================================================
# FUNCIONES
# ============================================================================

# 5. Parsear argumentos
parsear_argumentos() {
    while getopts "f:p:h" opt; do
        case "$opt" in
            f)
                if [ -f "$OPTARG" ]; then
                    HOSTS_A_VERIFICAR=$(awk '!/^[[:space:]]*(#|$)/ {printf "%s ", $0}' "$OPTARG")
                else
                    echo "Error: Archivo no existe: $OPTARG"
                    exit 1
                fi
                ;;
            p)
                for puerto in $OPTARG; do
                    if ! [[ "$puerto" =~ ^[0-9]+$ ]] ||
                       [ "$puerto" -lt 1 ] || [ "$puerto" -gt 65535 ]; then
                        echo "Error: Puerto no válido: $puerto"
                        exit 1
                    fi
                done
                PUERTOS_A_VERIFICAR="$OPTARG"
                ;;
            h)
                echo "Uso: $0 [-f archivo_hosts] [-p puertos]"
                echo "  -f: Archivo con lista de hosts (uno por línea)"
                echo "  -p: Puertos a verificar (separados por espacio, default: $PUERTOS_CRITICOS)"
                exit 0
                ;;
            *)
                echo "Opción no válida: -$OPTARG"
                exit 1
                ;;
        esac
    done
}

# 6. Verificar conectividad ping
verificar_ping() {
    local host="$1"

    timeout 3 ping -c 1 -W 2 "$host" &>/dev/null
}

# 7. Verificar puerto abierto con nc
verificar_puerto_nc() {
    local host="$1"
    local puerto="$2"

    if command -v nc &>/dev/null; then
        timeout 2 nc -zv "$host" "$puerto" &>/dev/null 2>&1
        return $?
    fi
    return 2
}

# 8. Verificar puerto abierto con /dev/tcp
verificar_puerto_devtcp() {
    local host="$1"
    local puerto="$2"

    timeout 2 bash -c \
        'exec 3<>"/dev/tcp/${1}/${2}"' _ "$host" "$puerto" &>/dev/null
}

# 9. Verificar puerto abierto (intenta múltiples métodos)
verificar_puerto() {
    local host="$1"
    local puerto="$2"

    # Intentar con nc primero
    if command -v nc &>/dev/null; then
        if timeout 2 nc -zv "$host" "$puerto" &>/dev/null 2>&1; then
            return 0
        fi
    fi

    # Intentar con nmap si está disponible
    if command -v nmap &>/dev/null; then
        if timeout 2 nmap -p "$puerto" "$host" 2>/dev/null | grep -q "open"; then
            return 0
        fi
    fi

    # Intentar con /dev/tcp
    if verificar_puerto_devtcp "$host" "$puerto"; then
        return 0
    fi

    return 1
}

# 10. Generar reporte detallado de host
reporte_host() {
    local host="$1"
    local puertos="$2"
    local puertos_abiertos=0
    local puertos_totales=0
    local puertos_cerrados=""

    echo "[*] Verificando: $host"

    # Verificar ping
    printf "  ├─ Ping: "
    if verificar_ping "$host"; then
        echo "✓ Respondiendo"
        registrar "red.sh" "PING: $host está respondiendo"
    else
        echo "✗ Sin respuesta"
        registrar "red.sh" "PING: $host no responde"
        echo "ESTADO|SIN_RESPUESTA|$host no responde al ping"
        return 1
    fi

    # Verificar puertos
    for puerto in $puertos; do
        puertos_totales=$((puertos_totales + 1))
        printf "  ├─ Puerto $puerto: "

        if verificar_puerto "$host" "$puerto"; then
            echo "✓ Abierto"
            puertos_abiertos=$((puertos_abiertos + 1))
            registrar "red.sh" "PUERTO: $host:$puerto ABIERTO"
        else
            echo "✗ Cerrado"
            puertos_cerrados="${puertos_cerrados}${puerto} "
            registrar "red.sh" "PUERTO: $host:$puerto CERRADO"
        fi
    done

    # Clasificar
    printf "  └─ Clasificación: "

    if [ "$puertos_abiertos" -eq "$puertos_totales" ]; then
        echo "✓ ACCESIBLE"
        echo "ESTADO|ACCESIBLE|$host"
    elif [ "$puertos_abiertos" -eq 0 ]; then
        echo "⚠ ACCESIBLE (sin puertos críticos abiertos)"
        echo "ESTADO|PARCIAL|$host - puertos cerrados: $puertos_cerrados"
    else
        echo "⚠ PARCIALMENTE ACCESIBLE"
        echo "ESTADO|PARCIAL|$host - puertos cerrados: $puertos_cerrados"
    fi
}

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================

parsear_argumentos "$@"

echo "╔════════════════════════════════════════╗"
echo "║     MONITOR DE CONECTIVIDAD DE RED      ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Hosts a verificar: $HOSTS_A_VERIFICAR"
echo "Puertos a verificar: $PUERTOS_A_VERIFICAR"
echo ""

registrar "red.sh" "INICIO: Monitoreo de red iniciado"

# Inicializar contadores
ACCESIBLES=0
PARCIALES=0
SIN_RESPUESTA=0
DETALLE_ALERTAS=""

# Procesar cada host
echo "╔════════════════════════════════════════╗"
echo "║          VERIFICACIÓN POR HOST           ║"
echo "╚════════════════════════════════════════╝"
echo ""

for host in $HOSTS_A_VERIFICAR; do
    [ -z "$host" ] && continue

    RESULTADO=$(reporte_host "$host" "$PUERTOS_A_VERIFICAR")
    LINEA_ESTADO=$(echo "$RESULTADO" | tail -n1)
    echo "$RESULTADO" | sed '$d'
    IFS='|' read -r _ ESTADO DETALLE <<< "$LINEA_ESTADO"

    case "$ESTADO" in
        ACCESIBLE)
            ACCESIBLES=$((ACCESIBLES + 1))
            ;;
        PARCIAL)
            PARCIALES=$((PARCIALES + 1))
            DETALLE_ALERTAS="${DETALLE_ALERTAS}- ${DETALLE}\n"
            ;;
        SIN_RESPUESTA)
            SIN_RESPUESTA=$((SIN_RESPUESTA + 1))
            DETALLE_ALERTAS="${DETALLE_ALERTAS}- ${DETALLE}\n"
            ;;
    esac

    echo ""
done

# Mostrar resumen
echo "╔════════════════════════════════════════╗"
echo "║              RESUMEN GENERAL             ║"
echo "╚════════════════════════════════════════╝"
echo ""
printf "Hosts Accesibles:         %2d\n" "$ACCESIBLES"
printf "Hosts Parcialmente Accesibles: %2d\n" "$PARCIALES"
printf "Hosts sin Respuesta:      %2d\n" "$SIN_RESPUESTA"
echo ""

# Alertar si hay hosts o puertos críticos sin respuesta
if [ "$SIN_RESPUESTA" -gt 0 ] || [ "$PARCIALES" -gt 0 ]; then
    echo "⚠ ALERTA: Se detectaron hosts o puertos críticos sin respuesta"
    printf "%b" "$DETALLE_ALERTAS"
    registrar "red.sh" "ALERTA: Sin respuesta=$SIN_RESPUESTA, Parciales=$PARCIALES"

    # Enviar notificación por Telegram
    MSG="🚨 ALERTA DE RED 🚨

Hosts sin respuesta: $SIN_RESPUESTA
Hosts parcialmente accesibles: $PARCIALES
Hosts accesibles: $ACCESIBLES

Detalles:
$(printf "%b" "$DETALLE_ALERTAS")

Por favor, verificar conexión de red"

    enviar_telegram "Alerta de Conectividad" "$MSG" || true
fi

registrar "red.sh" "CIERRE: Monitoreo de red finalizado - Accesibles: $ACCESIBLES, Parciales: $PARCIALES, Sin respuesta: $SIN_RESPUESTA"

exit 0
