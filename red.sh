#!/bin/bash





# ==============================================================================
# TU SCRIPT ORIGINAL (A partir de aquí sigue igual)
# ==============================================================================

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

# Se busca la ruta del comando ping para asegurar compatibilidad
PING_CMD=$(command -v ping)
if [ -z "$PING_CMD" ]; then
    echo "Error: El comando 'ping' no se encontró en el sistema."
    echo "Por favor, instale un paquete de utilidades de red (como 'iputils-ping' o 'inetutils') e intente de nuevo."
    exit 1
fi

# se preparan contadores y alerta
accesibles=0
parciales=0
sin_respuesta=0
mensaje=""

# se revisa cada host

# se revisa cada host
for equipo in $equipos
do
    echo "host: $equipo"
    abiertos=0
    cerrados=""
    ping_responde=0

    # 1. Prueba de Ping (Ahora es informativa, no bloqueante)
    if "$PING_CMD" -c 1 -W 2 "$equipo" > /dev/null; then
        echo "  [OK] Ping responde"
        registrar "red.sh" "$equipo responde ping"
        ping_responde=1
    else
        echo "  [INFO] Ping bloqueado o sin respuesta (ICMP bloqueado)"
        # IMPORTANTE: Eliminamos el 'continue' para que siga probando los puertos
    fi

    # 2. Prueba de Puertos (Esta es la prueba real de conectividad)
    for puerto in $puertos
    do
        if command -v nc > /dev/null 2>&1; then
            if timeout 2 nc -z "$equipo" "$puerto" > /dev/null 2>&1; then
                echo "  [OK] Puerto $puerto abierto"
                registrar "red.sh" "$equipo:$puerto abierto"
                abiertos=$((abiertos + 1))
            else
                echo "  [FAIL] Puerto $puerto cerrado/filtrado"
                cerrados="$cerrados $puerto"
            fi
        else
            if timeout 2 bash -c "echo > /dev/tcp/$equipo/$puerto" > /dev/null 2>&1; then
                echo "  [OK] Puerto $puerto abierto"
                registrar "red.sh" "$equipo:$puerto abierto"
                abiertos=$((abiertos + 1))
            else
                echo "  [FAIL] Puerto $puerto cerrado/filtrado"
                cerrados="$cerrados $puerto"
            fi
        fi
    done

    # 3. Clasificación basada en PUERTOS, no en Ping
    total_puertos=$(echo "$puertos" | wc -w)

    if [ "$abiertos" -gt 0 ]; then
        # Si hay puertos abiertos, el host está ACCESIBLE (aunque el ping falló)
        echo "  -> CLASIFICACIÓN: ACCESIBLE ($abiertos/$total_puertos puertos)"
        accesibles=$((accesibles + 1))
        registrar "red.sh" "$equipo accesible (puertos: $abiertos)"
    elif [ "$abiertos" -eq 0 ] && [ "$ping_responde" -eq 1 ]; then
        # Ping OK pero ningún puerto crítico abierto
        echo "  -> CLASIFICACIÓN: PARCIAL (Ping OK, sin puertos críticos)"
        parciales=$((parciales + 1))
        mensaje="${mensaje}⚠️ Host parcial: $equipo (Ping OK, puertos cerrados:$cerrados)
"
        registrar "red.sh" "$equipo parcial"
    else
        # Todo falló
        echo "  -> CLASIFICACIÓN: SIN RESPUESTA (Ping y Puertos fallaron)"
        sin_respuesta=$((sin_respuesta + 1))
        mensaje="${mensaje}❌ Host caído: $equipo
"
        registrar "red.sh" "$equipo sin respuesta total"
    fi

    echo ""
done

if [ -n "$mensaje" ]; then
    titulo="Alerta de Monitoreo de Red"
    enviar_telegram "$titulo" "$mensaje"
fi

echo "Resumen:"
echo "  Hosts accesibles: $accesibles"
echo "  Hosts parciales: $parciales"
echo "  Hosts sin respuesta: $sin_respuesta"     