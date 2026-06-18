#!/bin/bash
# este script muestra un diagnostico basico del sistema
# no se le deben mandar parametros porque toma los datos del equipo actual

# se valida que no se reciban parametros
if [ "$#" -ne 0 ]; then
    echo "Uso: $0"
    exit 1
fi

# si se interrumpe el diagnostico se sale de forma limpia
trap 'echo "diagnostico interrumpido"; exit 1' SIGINT SIGTERM

# se guarda la fecha actual en una variable
fecha=$(date '+%Y-%m-%d %H:%M:%S')

# se guarda el nombre del equipo
host=$(hostname)

# se guarda el usuario que esta ejecutando el script
usuario=$(id -un)

# se valida si existe el archivo donde viene la informacion del sistema
if [ -f /etc/os-release ]; then
    # se obtiene el nombre del sistema operativo
    sistema=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d "=" -f 2 | tr -d '"')
else
    # si no existe el archivo se deja como desconocido
    sistema="Desconocido"
fi

# se guarda la version del kernel
kernel=$(uname -r)

# se guarda la cantidad de nucleos del procesador
nucleos=$(nproc)

# se muestran los resultados del diagnostico
echo "diagnostico remoto"
echo "fecha: $fecha"
echo "host: $host"
echo "usuario: $usuario"
echo "sistema: $sistema"
echo "kernel: $kernel"
echo "nucleos cpu: $nucleos"
echo ""

# se muestra la memoria del equipo
echo "memoria:"
free -h
echo ""

# se muestra el espacio del disco raiz
echo "disco raiz:"
df -h /
echo ""

# se muestra cuanto tiempo lleva encendido el equipo
echo "tiempo encendido:"
uptime -p
echo ""

echo "diagnostico finalizado correctamente"
