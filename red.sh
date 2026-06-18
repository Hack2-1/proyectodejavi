#!/bin/bash
# este script revisa conectividad de red
# hace ping a hosts y revisa puertos importantes

# se busca y carga config.txt
ruta="$(cd "$(dirname "$0")" && pwd)"
config="$ruta/config.txt"

if [ ! -f "$config" ]; then
    echo "Error: no se encontro config.txt"
    exit 1
fi

source "$config"
validar_config || exit 1

# si se interrumpe el monitoreo de red se sale de forma limpia
trap 'echo "monitoreo de red interrumpido"; exit 1' SIGINT SIGTERM

# se crean los logs
mkdir -p "$LOG_DIR"

if [ "$?" -ne 0 ]; then
    echo "Error: no se pudo crear la carpeta de logs."
    exit 1
fi

# se toman hosts y puertos desde config.txt
equipos="$HOSTS_PING"
puertos="$PUERTOS_CRITICOS"

# se revisan opciones del usuario
while getopts "f:p:h" opcion
do
    case "$opcion" in
        f)
            archivo="$OPTARG"
            if [ ! -f "$archivo" ]; then
                echo "Error: el archivo '$archivo' no existe."
                exit 1
            fi
            equipos=$(awk '!/^[[:space:]]*(#|$)/ {printf "%s ", $0}' "$archivo")
            ;;
        p)
            puertos="$OPTARG"
            ;;
        h)
            echo "Uso: $0 [-f archivo_hosts] [-p \"22 80 443\"]"
            exit 0
            ;;
        *)
            echo "Opcion no valida"
            exit 1
            ;;
    esac
done

# se valida que los puertos sean numeros
for puerto in $puertos
do
    if ! [[ "$puerto" =~ ^[0-9]+$ ]] || [ "$puerto" -lt 1 ] || [ "$puerto" -gt 65535 ]; then
        echo "Error: puerto no valido $puerto"
        exit 1
    fi
done

echo "monitoreo de red"

# se preparan contadores y alerta
accesibles=0
parciales=0
sin_respuesta=0
mensaje=""

# se revisa cada host
for equipo in $equipos
do
    echo "host: $equipo"
    abiertos=0
    cerrados=""

    if ping -c 1 -W 2 "$equipo" > /dev/null 2>&1; then
        echo "ping: responde"
        registrar "red.sh" "$equipo responde ping"
    else
        echo "ping: no responde"
        registrar "red.sh" "$equipo no responde ping"
        sin_respuesta=$((sin_respuesta + 1))
        mensaje="${mensaje}Host sin respuesta: $equipo
"
        echo ""
        continue
    fi

    # se revisa cada puerto del host
    for puerto in $puertos
    do
        if command -v nc > /dev/null 2>&1; then
            if timeout 2 nc -z "$equipo" "$puerto" > /dev/null 2>&1; then
                echo "puerto $puerto: abierto"
                registrar "red.sh" "$equipo:$puerto abierto"
                abiertos=$((abiertos + 1))
            else
                echo "puerto $puerto: cerrado"
                registrar "red.sh" "$equipo:$puerto cerrado"
                cerrados="$cerrados $puerto"
            fi
        else
            if timeout 2 bash -c "echo > /dev/tcp/$equipo/$puerto" > /dev/null 2>&1; then
                echo "puerto $puerto: abierto"
                registrar "red.sh" "$equipo:$puerto abierto"
                abiertos=$((abiertos + 1))
            else
                echo "puerto $puerto: cerrado"
                registrar "red.sh" "$equipo:$puerto cerrado"
                cerrados="$cerrados $puerto"
            fi
        fi
    done

    # se clasifica el host segun sus puertos
    total_puertos=$(echo "$puertos" | wc -w)

    if [ "$abiertos" -eq "$total_puertos" ]; then
        echo "clasificacion: accesible"
        accesibles=$((accesibles + 1))
        registrar "red.sh" "$equipo accesible"
    elif [ "$abiertos" -eq 0 ]; then
        echo "clasificacion: sin puertos criticos"
        parciales=$((parciales + 1))
        mensaje="${mensaje}Host parcial: $equipo puertos cerrados:$cerrados
"
        registrar "red.sh" "$equipo parcial puertos cerrados:$cerrados"
    else
        echo "clasificacion: parcialmente accesible"
        parciales=$((parciales + 1))
        mensaje="${mensaje}Host parcial: $equipo puertos cerrados:$cerrados
"
        registrar "red.sh" "$equipo parcialmente accesible"
    fi

    echo ""
done

echo "resumen:"
echo "hosts accesibles: $accesibles"
echo "hosts parciales: $parciales"
echo "hosts sin respuesta: $sin_respuesta"

# si hubo fallas se manda telegram
if [ -n "$mensaje" ]; then
    enviar_telegram "Alerta de red" "$mensaje" || true
fi

echo "revision de red finalizada"
