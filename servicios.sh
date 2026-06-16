#!/bin/bash
# servicios.sh — Supervisión y reinicio automático de servicios
# Uso: ./servicios.sh [nombre_servicio]
# Verifica estado de servicios y intenta reiniciar los inactivos

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
SERVICIOS_CAIDOS=""

# 4. TRAP PARA MANEJO DE SEÑALES
trap 'echo "Supervisión interrumpida"; exit 1' SIGINT SIGTERM

# ============================================================================
# FUNCIONES
# ============================================================================

# 5. Verificar si un servicio está activo
verificar_servicio() {
    local servicio="$1"

    # Intentar con systemctl primero (moderno)
    if command -v systemctl &>/dev/null; then
        if systemctl is-active --quiet "$servicio" 2>/dev/null; then
            echo "ACTIVO"
            return 0
        elif systemctl cat "${servicio}.service" &>/dev/null; then
            echo "INACTIVO"
            return 1
        else
            echo "NO_EXISTE"
            return 2
        fi
    fi

    # Alternativa con service (compatibilidad)
    if command -v service &>/dev/null; then
        if service "$servicio" status &>/dev/null; then
            echo "ACTIVO"
            return 0
        elif [ -x "/etc/init.d/$servicio" ]; then
            echo "INACTIVO"
            return 1
        else
            echo "NO_EXISTE"
            return 2
        fi
    fi

    echo "DESCONOCIDO"
    return 2
}

# 6. Obtener detalles del servicio
obtener_detalles_servicio() {
    local servicio="$1"

    if command -v systemctl &>/dev/null; then
        systemctl status "$servicio" 2>/dev/null | head -n 5
    elif command -v service &>/dev/null; then
        service "$servicio" status 2>/dev/null | head -n 3
    fi
}

# 7. Reiniciar un servicio
reiniciar_servicio() {
    local servicio="$1"

    echo "[*] Intentando reiniciar servicio: $servicio"
    registrar "servicios.sh" "ACCION: Intentando reiniciar servicio $servicio"

    # Usar systemctl si está disponible
    if command -v systemctl &>/dev/null; then
        systemctl restart "$servicio" 2>/dev/null
        sleep 2

        if systemctl is-active --quiet "$servicio"; then
            echo "✓ Servicio $servicio reiniciado exitosamente"
            registrar "servicios.sh" "EXITO: Servicio $servicio reiniciado"
            enviar_telegram "Servicio Reiniciado" "El servicio <b>$servicio</b> fue reiniciado correctamente" || true
            return 0
        else
            echo "✗ Fallo al reiniciar $servicio"
            registrar "servicios.sh" "FALLO: No se pudo reiniciar servicio $servicio"
            enviar_telegram "Error en Reinicio" "No se pudo reiniciar el servicio <b>$servicio</b>" || true
            return 1
        fi
    fi

    # Usar service como alternativa
    if command -v service &>/dev/null; then
        service "$servicio" restart 2>/dev/null
        sleep 2

        if service "$servicio" status &>/dev/null; then
            echo "✓ Servicio $servicio reiniciado exitosamente"
            registrar "servicios.sh" "EXITO: Servicio $servicio reiniciado con service"
            enviar_telegram "Servicio Reiniciado" "El servicio <b>$servicio</b> fue reiniciado correctamente" || true
            return 0
        else
            echo "✗ Fallo al reiniciar $servicio"
            registrar "servicios.sh" "FALLO: No se pudo reiniciar $servicio con service"
            enviar_telegram "Error en Reinicio" "No se pudo reiniciar el servicio <b>$servicio</b>" || true
            return 1
        fi
    fi

    echo "✗ No hay herramientas disponibles para reiniciar servicios"
    return 2
}

# 8. Generar reporte de servicios
generar_reporte_servicios() {
    local servicios="$1"

    echo "╔════════════════════════════════════════════════════════╗"
    echo "║          ESTADO DE SERVICIOS DEL SISTEMA                ║"
    echo "╠════════════════════════════════════════════════════════╣"

    local contador_activos=0
    local contador_inactivos=0
    local contador_no_existentes=0
    local contador_desconocidos=0
    SERVICIOS_CAIDOS=""

    for servicio in $servicios; do
        estado=$(verificar_servicio "$servicio")

        case "$estado" in
            ACTIVO)
                printf "║ ✓ %-45s ACTIVO   ║\n" "$servicio"
                contador_activos=$((contador_activos + 1))
                registrar "servicios.sh" "ESTADO: Servicio $servicio ACTIVO"
                ;;
            INACTIVO)
                printf "║ ✗ %-45s INACTIVO ║\n" "$servicio"
                contador_inactivos=$((contador_inactivos + 1))
                SERVICIOS_CAIDOS="${SERVICIOS_CAIDOS}${servicio} "
                registrar "servicios.sh" "ESTADO: Servicio $servicio INACTIVO"
                ;;
            NO_EXISTE)
                printf "║ ? %-45s NO EXISTE ║\n" "$servicio"
                contador_no_existentes=$((contador_no_existentes + 1))
                registrar "servicios.sh" "ESTADO: Servicio $servicio NO EXISTE"
                ;;
            *)
                printf "║ ? %-45s UNKNOWN  ║\n" "$servicio"
                contador_desconocidos=$((contador_desconocidos + 1))
                registrar "servicios.sh" "ESTADO: Servicio $servicio DESCONOCIDO"
                ;;
        esac
    done

    echo "╠════════════════════════════════════════════════════════╣"
    printf "║ Total Activos: %-8d | Total Inactivos: %-10d ║\n" "$contador_activos" "$contador_inactivos"
    printf "║ No existen: %-10d | Desconocidos: %-12d ║\n" "$contador_no_existentes" "$contador_desconocidos"
    echo "╚════════════════════════════════════════════════════════╝"

    SERVICIOS_INVALIDOS=$((contador_no_existentes + contador_desconocidos))
}

# 9. Monitoreo completo con reinicio automático
monitoreo_completo() {
    local servicios="$1"

    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   SUPERVISOR DE SERVICIOS AUTOMÁTICO    ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    registrar "servicios.sh" "INICIO: Supervisor de servicios iniciado"

    # Generar reporte
    generar_reporte_servicios "$servicios"

    echo ""

    # Si hay servicios caidos, intentar reiniciarlos
    if [ -n "$SERVICIOS_CAIDOS" ] && [ "$SERVICIOS_CAIDOS" != " " ]; then
        echo "⚠ Se detectaron servicios inactivos. Intentando reiniciar..."
        echo ""

        for servicio in $SERVICIOS_CAIDOS; do
            [ -z "$servicio" ] && continue
            reiniciar_servicio "$servicio"
            echo ""
        done

        # Realizar segunda verificación
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔄 VERIFICACIÓN POSTERIOR AL REINICIO:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        generar_reporte_servicios "$servicios"
    else
        if [ "${SERVICIOS_INVALIDOS:-0}" -gt 0 ]; then
            echo "⚠ No hay servicios inactivos, pero existen nombres no válidos"
        else
            echo "✓ Todos los servicios están activos"
        fi
    fi
}

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================

# Determinar servicios a monitorear
SERVICIOS_A_MONITOREAR="$SERVICIOS"

if [ $# -gt 0 ]; then
    SERVICIOS_A_MONITOREAR="$@"
fi

# Ejecutar monitoreo
monitoreo_completo "$SERVICIOS_A_MONITOREAR"

registrar "servicios.sh" "CIERRE: Supervisor de servicios finalizado"

exit 0
