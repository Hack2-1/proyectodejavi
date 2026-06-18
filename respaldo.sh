#!/bin/bash
# este script crea respaldos comprimidos
# puede recibir directorios por parametro o usar los de config.txt

# se busca y carga config.txt
ruta="$(cd "$(dirname "$0")" && pwd)"
config="$ruta/config.txt"

if [ ! -f "$config" ]; then
    echo "Error: no se encontro config.txt"
    exit 1
fi

source "$config"
validar_config || exit 1

# si se interrumpe el respaldo se registra el error
trap 'echo "respaldo interrumpido"; registrar "respaldo.sh" "respaldo interrumpido"; exit 1' SIGINT SIGTERM

# se crean las carpetas necesarias
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

if [ "$?" -ne 0 ]; then
    echo "Error: no se pudieron crear las carpetas de trabajo."
    exit 1
fi

# si el usuario manda directorios se usan esos
# si no manda parametros se usan los directorios de config.txt
if [ "$#" -gt 0 ]; then
    directorios="$*"
else
    directorios="$DIRS_RESPALDO"
fi

# se valida que los directorios existan
for directorio in $directorios
do
    if [ ! -d "$directorio" ]; then
        echo "Error: el directorio '$directorio' no existe."
        exit 1
    fi
done

# se prepara el nombre del respaldo
fecha=$(date '+%Y%m%d_%H%M%S')
nombre="respaldo_$fecha.tar.gz"
archivo="$BACKUP_DIR/$nombre"

echo "creando respaldo..."
echo "destino: $archivo"

# se crea el respaldo comprimido
tar -czf "$archivo" $directorios 2>/dev/null

# se valida que tar haya funcionado
if [ "$?" -ne 0 ]; then
    echo "Error: no se pudo crear el respaldo."
    registrar "respaldo.sh" "error al crear respaldo"
    exit 1
fi

# se verifica que el respaldo se pueda leer
tar -tzf "$archivo" > /dev/null 2>&1

if [ "$?" -ne 0 ]; then
    echo "Error: el respaldo se creo pero no paso la verificacion."
    registrar "respaldo.sh" "respaldo no paso verificacion"
    exit 1
fi

# se valida que el archivo exista y tenga tamaño mayor a cero
if [ ! -s "$archivo" ]; then
    echo "Error: el respaldo esta vacio o no existe."
    registrar "respaldo.sh" "respaldo vacio o inexistente"
    exit 1
fi

# se eliminan respaldos antiguos segun la retencion de config.txt
if [ -n "$RESPALDO_RETENCION" ]; then
    find "$BACKUP_DIR" -name "respaldo_*.tar.gz" -type f -mtime +"$RESPALDO_RETENCION" -delete 2>/dev/null
fi

tamanio=$(du -h "$archivo" | awk '{print $1}')
fecha2=$(date '+%Y-%m-%d %H:%M:%S')

registrar "respaldo.sh" "respaldo generado $archivo tamaño $tamanio"
enviar_telegram "Respaldo generado" "Archivo: $archivo
Tamanio: $tamanio
Fecha: $fecha2" || true

echo "respaldo generado correctamente"
echo "archivo: $archivo"
