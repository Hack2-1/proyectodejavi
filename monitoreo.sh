#!/bin/bash
# este script monitorea cpu memoria y disco
# si algun valor pasa el limite se muestra una alerta

# se busca el archivo config.txt en la misma carpeta del script
ruta="$(cd "$(dirname "$0")" && pwd)"
config="$ruta/config.txt"

# se valida que exista config.txt
if [ ! -f "$config" ]; then
    echo "Error: no se encontro config.txt"
    exit 1
fi

# se carga la configuracion
source "$config"
validar_config || exit 1

# si se interrumpe el monitoreo se sale de forma limpia
trap 'echo "monitoreo interrumpido"; exit 1' SIGINT SIGTERM

# se guardan los umbrales que vienen de config.txt
limite_cpu="$UMBRAL_CPU"
limite_disco="$UMBRAL_DISCO"
limite_memoria="$UMBRAL_MEMORIA"

# se revisan las opciones que escribio el usuario
while getopts "c:d:m:h" opcion
do
    case "$opcion" in
        c) limite_cpu="$OPTARG" ;;
        d) limite_disco="$OPTARG" ;;
        m) limite_memoria="$OPTARG" ;;
        h)
            echo "Uso: $0 [-c cpu] [-d disco] [-m memoria]"
            exit 0
            ;;
        *)
            echo "Opcion no valida"
            exit 1
            ;;
    esac
done

# se valida que los umbrales sean numeros
for valor in "$limite_cpu" "$limite_disco" "$limite_memoria"
do
    if ! [[ "$valor" =~ ^[0-9]+$ ]]; then
        echo "Error: los umbrales deben ser numeros."
        exit 1
    fi
done

# se crea la carpeta de logs
mkdir -p "$LOG_DIR"

if [ "$?" -ne 0 ]; then
    echo "Error: no se pudo crear la carpeta de logs."
    exit 1
fi

# se obtiene el uso de cpu
cpu=$(top -bn1 2>/dev/null | awk '/Cpu/ {for(i=1;i<=NF;i++) if($i ~ /id/) {gsub(",", "", $(i-1)); print 100-$(i-1); exit}}')

if [ -z "$cpu" ]; then
    cpu=$(ps aux | awk 'NR>1 {suma+=$3} END {printf "%.1f", suma}')
fi

# se obtiene el uso del disco raiz
disco=$(df -P / | awk 'NR==2 {gsub("%", "", $5); print $5}')

# se obtiene el uso de memoria
memoria=$(free -m | awk 'NR==2 {printf "%.1f", (($2-$7)/$2)*100}')

# se muestran los datos obtenidos
echo "monitoreo del sistema"
echo "limite cpu: $limite_cpu%"
echo "limite disco: $limite_disco%"
echo "limite memoria: $limite_memoria%"
echo ""
echo "cpu: $cpu%"
echo "disco: $disco%"
echo "memoria: $memoria%"
echo ""

alerta="no"
mensaje_alerta=""
estado_cpu="normal"
estado_disco="normal"
estado_memoria="normal"

# se valida cpu
if awk -v valor="$cpu" -v limite="$limite_cpu" 'BEGIN {exit !(valor > limite)}'; then
    alerta="si"
    estado_cpu="alerta"
fi

# se valida disco
if [ "$disco" -gt "$limite_disco" ]; then
    alerta="si"
    estado_disco="alerta"
fi

# se valida memoria
if awk -v valor="$memoria" -v limite="$limite_memoria" 'BEGIN {exit !(valor > limite)}'; then
    alerta="si"
    estado_memoria="alerta"
fi

# se prepara el mensaje con todos los valores revisados
mensaje_alerta="CPU: $cpu% limite $limite_cpu% estado $estado_cpu
Disco: $disco% limite $limite_disco% estado $estado_disco
Memoria: $memoria% limite $limite_memoria% estado $estado_memoria"

# se muestra el resultado final
if [ "$alerta" = "si" ]; then
    echo "alertas encontradas:"
    echo "$mensaje_alerta"

    # se manda la alerta por telegram
    enviar_telegram "Alerta de monitoreo" "$mensaje_alerta"

    if [ "$?" -eq 0 ]; then
        echo "alerta enviada por telegram"
    else
        echo "no se pudo enviar la alerta por telegram"
    fi
else
    echo "estado normal"
fi

# se guarda registro en log
registrar "monitoreo.sh" "CPU=${cpu}% DISCO=${disco}% MEMORIA=${memoria}%"

echo "monitoreo finalizado"
