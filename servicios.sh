#!/bin/bash
# este script revisa servicios del sistema
# si un servicio esta detenido intenta reiniciarlo

# se busca y carga config.txt
ruta="$(cd "$(dirname "$0")" && pwd)"
config="$ruta/config.txt"

if [ ! -f "$config" ]; then
    echo "Error: no se encontro config.txt"
    exit 1
fi

source "$config"
validar_config || exit 1

# si se interrumpe el script se muestra mensaje
trap 'echo "revision de servicios interrumpida"; exit 1' SIGINT SIGTERM

# se crea la carpeta de logs
mkdir -p "$LOG_DIR"

if [ "$?" -ne 0 ]; then
    echo "Error: no se pudo crear la carpeta de logs."
    exit 1
fi

# si el usuario manda servicios por parametro se usan esos
# si no manda parametros se usan los servicios de config.txt
if [ "$#" -gt 0 ]; then
    lista_servicios="$*"
else
    lista_servicios="$SERVICIOS"
fi

# se valida que exista systemctl
if ! command -v systemctl > /dev/null 2>&1; then
    echo "Error: systemctl no esta disponible."
    exit 1
fi

caidos=""

echo "revision de servicios"

# se revisa cada servicio de la lista
for servicio in $lista_servicios
do
    echo "revisando: $servicio"

    if systemctl is-active --quiet "$servicio"; then
        echo "$servicio esta activo"
        registrar "servicios.sh" "$servicio activo"
    else
        echo "$servicio esta detenido"
        caidos="$caidos $servicio"
        registrar "servicios.sh" "$servicio detenido"

        # se intenta reiniciar usando root o sudo solamente en este comando
        if [ "$(id -u)" -eq 0 ]; then
            permiso="systemctl"
        elif command -v sudo > /dev/null 2>&1; then
            permiso="sudo systemctl"
        else
            permiso=""
        fi

        if [ -n "$permiso" ]; then
            echo "intentando reiniciar $servicio"
            $permiso restart "$servicio"

            if systemctl is-active --quiet "$servicio"; then
                echo "$servicio reiniciado correctamente"
                registrar "servicios.sh" "$servicio reiniciado"
                enviar_telegram "Servicio reiniciado" "Servicio: $servicio
Resultado: reiniciado correctamente" || true
                # Remover de la lista de caídos para evitar doble notificación al final
                caidos="${caidos/ $servicio/}"
            else
                echo "no se pudo reiniciar $servicio"
                registrar "servicios.sh" "no se pudo reiniciar $servicio"
                enviar_telegram "Servicio caido" "Servicio: $servicio
Resultado: no se pudo reiniciar" || true
            fi
        else
            echo "no se pudo reiniciar porque no hay permisos ni sudo"
            enviar_telegram "Servicio caido" "Servicio: $servicio
Resultado: sin permisos para reiniciar" || true
        fi
    fi

    echo ""
done

# se envia alerta si hubo servicios caidos
if [ -n "$caidos" ]; then
    enviar_telegram "Servicios caidos" "Servicios con problema:$caidos" || true
else
    echo "todos los servicios revisados estan activos"
fi

echo "revision finalizada"
