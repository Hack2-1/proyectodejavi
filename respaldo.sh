#!/bin/bash
# Script para generar respaldos comprimidos de directorios especificados.
# Cumple con validación de tamaño, rotación, logs y notificaciones del Proyecto Integrador.

#Extrae el directorio en donde estamos situados y en donde se encuentra config.txt
DIRECTORIO_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_TXT="$DIRECTORIO_BASE/config.txt"

# Carga del archivo de configuración y comprueba que existe
if [ -f "$CONFIG_TXT" ]; then
    source "$CONFIG_TXT"
else
    echo "Error: No se encuentra el archivo config.txt en $DIRECTORIO_BASE"
    exit 1
fi

validar_config || exit 1

# Captura de señales para asegurar salidas limpias y registrar en log si se cancela
trap 'echo "Respaldo interrumpido por el usuario."; registrar "respaldo" "Respaldo cancelado manualmente"; exit 1' SIGINT SIGTERM

# Se crean las carpetas de trabajo si no existen
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

if [ $? -ne 0 ]; then
    echo "Error: No se pudieron crear los directorios de logs o respaldos."
    exit 1
fi

# Si el usuario manda directorios por argumento se usan, sino, lee del config.txt
if [ "$#" -gt 0 ]; then
    directorios_a_respaldar=("$@")
else
    # shellcheck disable=SC2206
    directorios_a_respaldar=($DIRS_RESPALDO)
fi

#Validación de existencia de cada directorio
for dir in "${directorios_a_respaldar[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Error: El directorio origen '$dir' no existe."
        registrar "respaldo" "Fallo: Directorio origen inexistente ($dir)"
        exit 1
    fi
done

# EJECUCIÓN DEL RESPALDO
fecha_actual=$(date +"%Y-%m-%d_%H-%M-%S")

# Determinar formato de compresión
case "$RESPALDO_COMPRESION" in
    "bzip2") ext="tar.bz2"; flag_comp="-cj"; flag_test="-tj" ;;
    "xz")    ext="tar.xz";  flag_comp="-cJ"; flag_test="-tJ" ;;
    *)       ext="tar.gz";  flag_comp="-cz"; flag_test="-tz" ;;
esac

nombre_archivo="respaldo_$fecha_actual.$ext"
ruta_completa="$BACKUP_DIR/$nombre_archivo"

echo "Generando respaldo de los directorios: ${directorios_a_respaldar[*]}"
echo "Destino: $ruta_completa"

# Compresión de los directorios silenciando errores menores
tar "$flag_comp" -f "$ruta_completa" "${directorios_a_respaldar[@]}" 2>/dev/null

#COMPROBACION DEL RESPALDO

#Comprueba si el anterior comando tiene fallos
if [ $? -ne 0 ]; then
    echo "Error: Fallo la ejecución del comando tar."
    registrar "respaldo" "Error crítico al intentar crear el respaldo con tar."
    enviar_telegram "Fallo en Respaldo" "Error al intentar comprimir: ${directorios_a_respaldar[*]}"
    exit 1
fi

#1. Validar que el archivo se puede leer y no está corrupto
tar "$flag_test" -f "$ruta_completa" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: El respaldo se creó pero el archivo está corrupto."
    registrar "respaldo" "El respaldo generado no pasó la prueba de integridad."
    exit 1
fi

# 2. Validar que el archivo exista y su tamaño sea mayor a 0 bytes
if [ ! -s "$ruta_completa" ]; then
    echo "Error: El archivo de respaldo está vacío (0 bytes) o no se creó."
    registrar "respaldo" "Fallo: El archivo de respaldo resultante pesa 0 bytes."
    exit 1
fi

# LIMPIEZA DE RESPALDOS ANTIGUOS (OPCIONAL SEGÚN CONFIG)
if [ -n "$RESPALDO_RETENCION" ]; then
    #Busa respaldos de acuerdo a la decha establecida y los borra silenciosamente
    find "$BACKUP_DIR" -name "respaldo_*.tar.*" -type f -mtime +"$RESPALDO_RETENCION" -delete 2>/dev/null
fi

# REPORTE Y NOTIFICACIÓN

# Extraer el peso formateado
peso_formateado=$(du -sh "$ruta_completa" | awk '{print $1}')
fecha_legible=$(date '+%Y-%m-%d %H:%M:%S')

# Guardar en Logs
registrar "respaldo" "Éxito: Respaldo $ruta_completa creado. Tamaño: $peso_formateado."

# Notificar por Telegram
mensaje_telegram="✅ <b>Respaldo Completado</b>
<b>Ruta:</b> $ruta_completa
<b>Tamaño:</b> $peso_formateado
<b>Fecha:</b> $fecha_legible"

enviar_telegram "Reporte de Respaldo" "$mensaje_telegram" || true

echo "Respaldo validado y generado exitosamente con un tamaño de $peso_formateado."
exit 0

