#!/bin/bash
# este script copia y ejecuta un script en equipos remotos por ssh
# usa un archivo de hosts para saber a que equipos conectarse

# se busca y carga config.txt
ruta="$(cd "$(dirname "$0")" && pwd)"
config="$ruta/config.txt"

if [ ! -f "$config" ]; then
    echo "Error: no se encontro config.txt"
    exit 1
fi

source "$config"
validar_config || exit 1

# si se interrumpe la ejecucion remota se sale de forma limpia
trap 'echo "ejecucion remota interrumpida"; exit 1' SIGINT SIGTERM

# se valida que se reciba minimo el script local
if [ "$#" -lt 1 ]; then
    echo "Uso: $0 <script_local> [archivo_hosts]"
    exit 1
fi

# se guardan los argumentos en variables
script="$1"
archivo="${2:-$HOSTS_REMOTOS_FILE}"

# se valida que el script local exista
if [ ! -f "$script" ]; then
    echo "Error: el script '$script' no existe."
    exit 1
fi

# se valida el archivo de hosts
if [ ! -f "$archivo" ] || [ ! -s "$archivo" ]; then
    echo "Error: el archivo de hosts no existe o esta vacio."
    exit 1
fi

# se crean carpetas necesarias
mkdir -p "$LOG_DIR" "$REPORTS_DIR"

if [ "$?" -ne 0 ]; then
    echo "Error: no se pudieron crear las carpetas de trabajo."
    exit 1
fi

# se preparan variables de trabajo
fecha=$(date '+%Y%m%d_%H%M%S')
fecha2=$(date '+%Y-%m-%d %H:%M:%S')
nombre=$(basename "$script")
script2="/tmp/$nombre"
reporte="$REPORTS_DIR/remoto_$fecha.txt"

# se inicia el reporte
{
    echo "reporte de ejecucion remota"
    echo "fecha: $fecha2"
    echo "script local: $script"
    echo "archivo de hosts: $archivo"
    echo "usuario remoto: $USUARIO_REMOTO"
    echo "puerto ssh: $PUERTO_SSH"
    echo "script temporal en la vm: $script2"
    echo ""
    echo "resultado por servidor"
    echo "----------------------------------------"
} > "$reporte"

echo "iniciando ejecucion remota"

# se lee cada host del archivo
while IFS= read -r host
do
    [ -z "$host" ] && continue
    echo "$host" | grep -q "^[[:space:]]*#" && continue

    echo "host: $host"

    # si el host ya trae usuario@ip se usa asi
    # si solo trae ip se agrega el usuario de config.txt
    if echo "$host" | grep -q "@"; then
        servidor="$host"
    else
        servidor="${USUARIO_REMOTO}@${host}"
    fi

    {
        echo ""
        echo "servidor: $host"
        echo "conexion usada: $servidor"
    } >> "$reporte"

    # se crea un reporte individual por cada host
    host_limpio=$(echo "$host" | tr '/:@' '___')
    reporte_host="$REPORTS_DIR/remoto_${host_limpio}_$fecha.txt"
    {
        echo "reporte individual de ejecucion remota"
        echo "fecha: $fecha2"
        echo "servidor: $host"
        echo "conexion usada: $servidor"
        echo "script local: $script"
        echo "script temporal: $script2"
        echo ""
    } > "$reporte_host"

    # se prueba conexion ssh
    echo "probando conexion ssh..."
    timeout "$TIMEOUT_SSH" ssh -p "$PUERTO_SSH" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$servidor" "exit 0" > /dev/null 2>&1

    if [ "$?" -ne 0 ]; then
        echo "no se pudo conectar por ssh"
        {
            echo "estado: error de conexion ssh"
            echo "----------------------------------------"
        } >> "$reporte"
        echo "estado: error de conexion ssh" >> "$reporte_host"
        continue
    fi

    echo "conexion ssh correcta"
    echo "conexion ssh: correcta" >> "$reporte"
    echo "conexion ssh: correcta" >> "$reporte_host"

    # se copia el script
    echo "copiando script..."
    scp -P "$PUERTO_SSH" -o StrictHostKeyChecking=accept-new "$script" "$servidor:$script2" > /dev/null 2>&1

    if [ "$?" -ne 0 ]; then
        echo "no se pudo copiar el script"
        {
            echo "estado: error al copiar el script"
            echo "----------------------------------------"
        } >> "$reporte"
        echo "estado: error al copiar el script" >> "$reporte_host"
        continue
    fi

    echo "script copiado correctamente"
    echo "copia del script: correcta" >> "$reporte"
    echo "copia del script: correcta" >> "$reporte_host"

    # se ejecuta el script remoto
    echo "ejecutando script remoto..."
    salida=$(ssh -p "$PUERTO_SSH" -o StrictHostKeyChecking=accept-new "$servidor" "bash '$script2'" 2>&1)
    codigo="$?"

    echo "$salida"

    {
        echo ""
        echo "salida del script:"
        echo "----------------------------------------"
        echo "$salida"
        echo "----------------------------------------"
    } >> "$reporte"

    {
        echo ""
        echo "salida del script:"
        echo "----------------------------------------"
        echo "$salida"
        echo "----------------------------------------"
    } >> "$reporte_host"

    if [ "$codigo" -eq 0 ]; then
        echo "estado: ejecutado correctamente" >> "$reporte"
        echo "estado: ejecutado correctamente" >> "$reporte_host"
        registrar "remoto.sh" "$host ejecucion correcta"
    else
        echo "estado: error al ejecutar" >> "$reporte"
        echo "estado: error al ejecutar" >> "$reporte_host"
        registrar "remoto.sh" "$host error al ejecutar"
    fi

    # se borra el script remoto
    ssh -p "$PUERTO_SSH" -o StrictHostKeyChecking=accept-new "$servidor" "rm -f '$script2'" > /dev/null 2>&1
    echo "limpieza: script temporal eliminado" >> "$reporte"
    echo "limpieza: script temporal eliminado" >> "$reporte_host"
    echo "----------------------------------------" >> "$reporte"
    echo ""
done < "$archivo"

enviar_telegram "Ejecucion remota" "Reporte: $reporte" || true

echo "ejecucion remota finalizada"
echo "reporte: $reporte"
