#!/bin/bash
# remoto.sh — Ejecución remota de scripts en múltiples hosts
# Uso: ./remoto.sh <script_local> [archivo_hosts]
# Copia un script a máquinas remotas, lo ejecuta y genera reporte

# 1. INICIALIZACIÓN Y VALIDACIONES
CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: No se encontró config.txt"
    exit 1
fi

source "$CONFIG_FILE"
validar_config || exit 1

# 2. VALIDAR ARGUMENTOS
if [ $# -lt 1 ]; then
    echo "Uso: $0 <script_local> [archivo_hosts]"
    echo "Ejemplo: $0 ./diagnostico.sh /opt/sistema-servicios/hosts.txt"
    exit 1
fi

SCRIPT_LOCAL="$1"
ARCHIVO_HOSTS="${2:-$HOSTS_REMOTOS_FILE}"

# 3. VALIDAR QUE EL SCRIPT LOCAL EXISTE
if [ ! -f "$SCRIPT_LOCAL" ]; then
    echo "Error: Script local no existe: $SCRIPT_LOCAL"
    exit 1
fi

# 4. CREAR DIRECTORIO DE LOGS Y REPORTES
mkdir -p "$LOG_DIR" 2>/dev/null || {
    echo "Error: No se pudo crear el directorio de logs: $LOG_DIR"
    exit 1
}

if ! mkdir -p "$REPORTS_DIR" 2>/dev/null ||
   [ ! -w "$REPORTS_DIR" ]; then
    REPORTS_DIR="${HOME}/.local/state/sistema-servicios/reportes"
    mkdir -p "$REPORTS_DIR" || {
        echo "Error: No se pudo crear el directorio de reportes: $REPORTS_DIR"
        exit 1
    }
    echo "Advertencia: Los reportes se guardarán en $REPORTS_DIR"
fi

# 5. VARIABLES DE TRABAJO
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
NOMBRE_SCRIPT=$(basename "$SCRIPT_LOCAL")
REPORTE_GENERAL="${REPORTS_DIR}/remoto_${TIMESTAMP}.txt"
SCRIPT_REMOTO="/tmp/${NOMBRE_SCRIPT}"

# 6. TRAP PARA MANEJO DE SEÑALES
trap 'echo "Ejecución remota interrumpida"; exit 1' SIGINT SIGTERM

# ============================================================================
# FUNCIONES
# ============================================================================

# 7. Verificar conexión SSH no interactiva
verificar_conexion_ssh() {
    local host="$1"
    local usuario="$2"

    timeout "$TIMEOUT_SSH" ssh -p "$PUERTO_SSH" \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=accept-new \
        "${usuario}@${host}" "exit 0" &>/dev/null
}

# 8. Validar archivo de hosts
validar_archivo_hosts() {
    local archivo="$1"

    if [ ! -f "$archivo" ]; then
        echo "Error: Archivo de hosts no existe: $archivo"
        registrar "remoto.sh" "ERROR: Archivo de hosts no encontrado: $archivo"
        exit 1
    fi

    if [ ! -s "$archivo" ]; then
        echo "Error: Archivo de hosts está vacío: $archivo"
        registrar "remoto.sh" "ERROR: Archivo de hosts vacío: $archivo"
        exit 1
    fi
}

# 9. Copiar script a máquina remota
copiar_script_remoto() {
    local host="$1"
    local script="$2"
    local usuario="$3"
    local salida_scp

    echo "[*] Copiando script a $host..."

    # Usar scp con timeout
    salida_scp=$(timeout "$TIMEOUT_SSH" scp -P "$PUERTO_SSH" \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=accept-new \
        "$script" "${usuario}@${host}:${SCRIPT_REMOTO}" 2>&1)

    if [ $? -eq 0 ]; then
        echo "✓ Script copiado a $host"
        return 0
    else
        echo "✗ Fallo al copiar script a $host"
        [ -n "$salida_scp" ] && echo "  Detalle: $salida_scp"
        return 1
    fi
}

# 10. Ejecutar script en máquina remota
ejecutar_script_remoto() {
    local host="$1"
    local usuario="$2"
    local script="$3"

    echo "[*] Ejecutando script en $host..."

    # Ejecutar por SSH y capturar salida
    local salida
    salida=$(timeout "$TIMEOUT_SSH" ssh -p "$PUERTO_SSH" \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=accept-new \
        "${usuario}@${host}" \
        "bash '$script' 2>&1" 2>&1)

    local codigo_salida=$?

    echo "$salida"
    return $codigo_salida
}

# 11. Limpiar script en máquina remota
limpiar_script_remoto() {
    local host="$1"
    local usuario="$2"
    local script="$3"

    timeout "$TIMEOUT_SSH" ssh -p "$PUERTO_SSH" \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=accept-new \
        "${usuario}@${host}" \
        "rm -f '$script'" 2>/dev/null
}

# 12. Generar reporte individual por host
generar_reporte_host() {
    local host="$1"
    local usuario="$2"
    local script_local="$3"
    local salida_ejecucion="$4"
    local codigo_salida="$5"

    local timestamp_reporte=$(date +"${TIMESTAMP_FORMAT}")
    local estado="✓ ÉXITO"

    if [ $codigo_salida -ne 0 ]; then
        estado="✗ ERROR (código: $codigo_salida)"
    fi

    # Crear directorio individual para host si no existe
    local dir_host="${REPORTS_DIR}/${host}_${TIMESTAMP}"
    mkdir -p "$dir_host"

    # Generar reporte individual
    local reporte_host="${dir_host}/ejecucion.txt"
    {
        echo "════════════════════════════════════════════════════"
        echo "REPORTE DE EJECUCIÓN REMOTA"
        echo "════════════════════════════════════════════════════"
        echo ""
        echo "Host: $host"
        echo "Usuario: $usuario"
        echo "Script: $(basename "$script_local")"
        echo "Fecha: $timestamp_reporte"
        echo "Estado: $estado"
        echo ""
        echo "────────────────────────────────────────────────────"
        echo "SALIDA DE EJECUCIÓN:"
        echo "────────────────────────────────────────────────────"
        echo "$salida_ejecucion"
        echo ""
        echo "════════════════════════════════════════════════════"
    } > "$reporte_host"

    echo "$dir_host"
}

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================

echo "╔════════════════════════════════════════╗"
echo "║   EJECUTOR DE SCRIPTS REMOTOS           ║"
echo "╚════════════════════════════════════════╝"
echo ""

registrar "remoto.sh" "INICIO: Ejecución remota iniciada - Script: $NOMBRE_SCRIPT"

# Validar archivo de hosts
validar_archivo_hosts "$ARCHIVO_HOSTS"

# Inicializar reporte general
{
    echo "════════════════════════════════════════════════════"
    echo "REPORTE GENERAL DE EJECUCIÓN REMOTA"
    echo "════════════════════════════════════════════════════"
    echo "Timestamp: $(date +"${TIMESTAMP_FORMAT}")"
    echo "Script: $NOMBRE_SCRIPT"
    echo "Archivo de hosts: $ARCHIVO_HOSTS"
    echo ""
} > "$REPORTE_GENERAL"

# Procesar cada host
CONTADOR_EXITO=0
CONTADOR_FALLO=0

while IFS= read -r linea || [ -n "$linea" ]; do
    # Ignorar líneas vacías y comentarios
    [[ "$linea" =~ ^[[:space:]]*$ ]] && continue
    [[ "$linea" =~ ^[[:space:]]*# ]] && continue

    # Parsear línea (formato: host o usuario@host)
    if [[ "$linea" == *"@"* ]]; then
        HOST=$(echo "$linea" | cut -d'@' -f2)
        USUARIO=$(echo "$linea" | cut -d'@' -f1)
    else
        HOST="$linea"
        USUARIO="$USUARIO_REMOTO"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Procesando host: $HOST (usuario: $USUARIO)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Verificar autenticación por llave antes de copiar
    if ! verificar_conexion_ssh "$HOST" "$USUARIO"; then
        echo "✗ No hay acceso SSH no interactivo a ${USUARIO}@${HOST}"
        echo "  Configura una llave con: ssh-copy-id ${USUARIO}@${HOST}"
        echo "✗ $HOST: Autenticación SSH por llave no disponible" >> "$REPORTE_GENERAL"
        CONTADOR_FALLO=$((CONTADOR_FALLO + 1))
        registrar "remoto.sh" "FALLO: Autenticación SSH por llave no disponible en $HOST"
        echo ""
        continue
    fi

    # Copiar script
    if copiar_script_remoto "$HOST" "$SCRIPT_LOCAL" "$USUARIO"; then

        # Ejecutar script
        SALIDA=$(ejecutar_script_remoto "$HOST" "$USUARIO" "$SCRIPT_REMOTO")
        CODIGO_SALIDA=$?

        echo "$SALIDA"
        echo ""

        # Generar reporte individual
        DIR_REPORTE=$(generar_reporte_host "$HOST" "$USUARIO" "$SCRIPT_LOCAL" "$SALIDA" "$CODIGO_SALIDA")

        # Actualizar reporte general
        if [ $CODIGO_SALIDA -eq 0 ]; then
            echo "✓ $HOST: ÉXITO (Reporte: $DIR_REPORTE)" >> "$REPORTE_GENERAL"
            CONTADOR_EXITO=$((CONTADOR_EXITO + 1))
            registrar "remoto.sh" "EXITO: Ejecución en $HOST completada"
        else
            echo "✗ $HOST: ERROR (código: $CODIGO_SALIDA, Reporte: $DIR_REPORTE)" >> "$REPORTE_GENERAL"
            CONTADOR_FALLO=$((CONTADOR_FALLO + 1))
            registrar "remoto.sh" "ERROR: Fallo en ejecución remota en $HOST"
        fi

        # Limpiar script remoto
        limpiar_script_remoto "$HOST" "$USUARIO" "$SCRIPT_REMOTO"
    else
        echo "✗ $HOST: No se pudo conectar" >> "$REPORTE_GENERAL"
        CONTADOR_FALLO=$((CONTADOR_FALLO + 1))
        registrar "remoto.sh" "FALLO: No se pudo conectar a $HOST"
    fi

done < "$ARCHIVO_HOSTS"

# Finalizar reporte general
{
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "RESUMEN"
    echo "════════════════════════════════════════════════════"
    echo "Hosts procesados exitosamente: $CONTADOR_EXITO"
    echo "Hosts con errores: $CONTADOR_FALLO"
    echo "Total: $((CONTADOR_EXITO + CONTADOR_FALLO))"
    echo ""
    echo "Reportes individuales en: $REPORTS_DIR"
    echo "════════════════════════════════════════════════════"
} >> "$REPORTE_GENERAL"

# Mostrar resumen
echo ""
echo "╔════════════════════════════════════════╗"
echo "║            EJECUCIÓN COMPLETADA        ║"
echo "╚════════════════════════════════════════╝"
cat "$REPORTE_GENERAL" | tail -20

registrar "remoto.sh" "CIERRE: Ejecución remota finalizada - Éxito: $CONTADOR_EXITO, Fallo: $CONTADOR_FALLO"

if [ "$CONTADOR_FALLO" -eq 0 ]; then
    TITULO_TELEGRAM="Ejecución Remota Completada"
else
    TITULO_TELEGRAM="Ejecución Remota con Errores"
fi

MSG="Script: ${NOMBRE_SCRIPT}
Hosts exitosos: ${CONTADOR_EXITO}
Hosts con errores: ${CONTADOR_FALLO}
Total: $((CONTADOR_EXITO + CONTADOR_FALLO))
Reporte: ${REPORTE_GENERAL}"

enviar_telegram "$TITULO_TELEGRAM" "$MSG" || true

exit 0
