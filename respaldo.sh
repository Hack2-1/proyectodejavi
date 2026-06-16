#!/bin/bash
# respaldo.sh — Gestor automatizado de respaldos
# Uso: ./respaldo.sh [directorio_a_respaldar] (o usa config.txt)
# Realiza compresión, verifica integridad y notifica por Telegram

# 1. INICIALIZACIÓN Y VALIDACIONES
CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: No se encontró config.txt en el directorio del script"
    exit 1
fi

source "$CONFIG_FILE"
validar_config || exit 1

# 2. CREAR DIRECTORIOS NECESARIOS
mkdir -p "$LOG_DIR" "$BACKUP_DIR" 2>/dev/null || {
    echo "Error: No se pudieron crear los directorios de trabajo"
    exit 1
}

# 3. VARIABLES DE TRABAJO
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 4. TRAP PARA MANEJO DE SEÑALES
trap 'echo "Respaldo interrumpido"; registrar "respaldo.sh" "INTERRUMPIDO: Respaldo cancelado"; exit 1' SIGINT SIGTERM

# ============================================================================
# FUNCIONES
# ============================================================================

# 5. Validar que los directorios existan
validar_directorios() {
    local directorios="$1"

    for directorio in $directorios; do
        if [ ! -d "$directorio" ]; then
            echo "⚠ Advertencia: Directorio no existe: $directorio"
            registrar "respaldo.sh" "ADVERTENCIA: Directorio no encontrado para respaldo: $directorio"
        fi
    done
}

# 6. Crear archivo de respaldo comprimido
crear_respaldo() {
    local dirs_a_respaldar="$1"
    local nombre_archivo="respaldo_${TIMESTAMP}.tar.${RESPALDO_COMPRESION}"
    local ruta_completa="${BACKUP_DIR}/${nombre_archivo}"

    # Determinar opciones de compresión
    local opcion_compresion=""
    case "$RESPALDO_COMPRESION" in
        gzip)
            opcion_compresion="-z"
            ;;
        bzip2)
            opcion_compresion="-j"
            ;;
        xz)
            opcion_compresion="-J"
            ;;
        *)
            echo "Error: Formato de compresión no soportado: $RESPALDO_COMPRESION"
            return 1
            ;;
    esac

    # Crear respaldo
    echo "[*] Iniciando respaldo en: $ruta_completa" >&2
    tar $opcion_compresion -cf "$ruta_completa" $dirs_a_respaldar

    if [ $? -ne 0 ]; then
        echo "Error: No se pudo crear el respaldo"
        registrar "respaldo.sh" "ERROR: Fallo al crear respaldo comprimido"
        return 1
    fi

    echo "$ruta_completa"
}

# 7. Verificar integridad del respaldo
verificar_respaldo() {
    local archivo_respaldo="$1"

    # Verificar que el archivo existe
    if [ ! -f "$archivo_respaldo" ]; then
        echo "Error: Archivo de respaldo no existe: $archivo_respaldo"
        return 1
    fi

    # Verificar que el tamaño es mayor a 0
    local tamano
    tamano=$(stat -f%z "$archivo_respaldo" 2>/dev/null || stat -c%s "$archivo_respaldo" 2>/dev/null)

    if [ "$tamano" -le 0 ]; then
        echo "Error: Archivo de respaldo vacío o corrupto"
        registrar "respaldo.sh" "ERROR: Respaldo corrupto (tamaño: $tamano bytes)"
        return 1
    fi

    # Validar integridad del archivo tar
    case "$RESPALDO_COMPRESION" in
        gzip)  tar -tzf "$archivo_respaldo" >/dev/null 2>&1 ;;
        bzip2) tar -tjf "$archivo_respaldo" >/dev/null 2>&1 ;;
        xz)    tar -tJf "$archivo_respaldo" >/dev/null 2>&1 ;;
    esac

    if [ $? -ne 0 ]; then
        echo "Error: Respaldo corrupto o no es un archivo tar válido"
        registrar "respaldo.sh" "ERROR: Archivo tar inválido"
        return 1
    fi

    echo "✓ Respaldo verificado correctamente"
    echo "  Tamaño: $(numfmt --to=iec-i --suffix=B "$tamano" 2>/dev/null || echo "${tamano} bytes")"
    return 0
}

# 8. Limpiar respaldos antiguos
limpiar_respaldos_antiguos() {
    local dias_retencion="$RESPALDO_RETENCION"

    echo "[*] Limpiando respaldos con más de $dias_retencion días..."
    find "$BACKUP_DIR" -name "respaldo_*.tar.*" -type f -mtime "+$dias_retencion" -delete

    registrar "respaldo.sh" "MANTENIMIENTO: Respaldos antiguos eliminados (retencion: $dias_retencion días)"
}

# 9. Obtener información del respaldo
obtener_info_respaldo() {
    local archivo_respaldo="$1"
    local tamano
    local tamano_legible
    local fecha

    tamano=$(stat -f%z "$archivo_respaldo" 2>/dev/null || stat -c%s "$archivo_respaldo" 2>/dev/null)
    tamano_legible=$(numfmt --to=iec-i --suffix=B "$tamano" 2>/dev/null || echo "${tamano} bytes")
    fecha=$(stat -f"%Sm -U" "$archivo_respaldo" 2>/dev/null || stat -c%y "$archivo_respaldo" 2>/dev/null | cut -d' ' -f1-2)

    echo "Archivo: $(basename "$archivo_respaldo")"
    echo "Tamaño: $tamano_legible"
    echo "Fecha: $fecha"
    echo "Ruta: $archivo_respaldo"
}

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================

registrar "respaldo.sh" "INICIO: Proceso de respaldo iniciado"

# Determinar directorios a respaldar
DIRS_RESPALDO_FINAL="$DIRS_RESPALDO"
if [ $# -gt 0 ]; then
    DIRS_RESPALDO_FINAL="$@"
fi

echo "╔════════════════════════════════════════╗"
echo "║     GESTOR DE RESPALDOS AUTOMÁTICO      ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Validar directorios
validar_directorios "$DIRS_RESPALDO_FINAL"

# Crear respaldo
if ! ARCHIVO_RESPALDO=$(crear_respaldo "$DIRS_RESPALDO_FINAL"); then
    echo "Fallo al crear el respaldo"
    registrar "respaldo.sh" "ERROR: No se pudo completar el respaldo"
    exit 1
fi

echo ""

# Verificar integridad
if verificar_respaldo "$ARCHIVO_RESPALDO"; then
    echo ""
    echo "📦 DETALLES DEL RESPALDO:"
    obtener_info_respaldo "$ARCHIVO_RESPALDO"

    # Enviar notificación por Telegram
    MSG="✓ Respaldo completado correctamente
Archivo: $(basename "$ARCHIVO_RESPALDO")
Tamaño: $(stat -f%z "$ARCHIVO_RESPALDO" 2>/dev/null || stat -c%s "$ARCHIVO_RESPALDO" 2>/dev/null) bytes
Fecha: $(date +"${TIMESTAMP_FORMAT}")"

    enviar_telegram "Respaldo Completado" "$MSG" || true
    registrar "respaldo.sh" "COMPLETADO: Respaldo exitoso - $ARCHIVO_RESPALDO"

    # Limpiar respaldos antiguos
    limpiar_respaldos_antiguos

    exit 0
else
    echo "Fallo en la verificación del respaldo"
    registrar "respaldo.sh" "ERROR: Verificación de respaldo fallida"
    exit 1
fi
