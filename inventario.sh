#!/bin/bash
# este script genera un inventario de hardware y software del sistema
# el reporte se guarda en un archivo de texto

# se valida que no se reciban parametros
if [ "$#" -ne 0 ]; then
    echo "Uso: $0"
    exit 1
fi

# se busca el archivo config.txt en la misma carpeta del script
ruta="$(cd "$(dirname "$0")" && pwd)"
config="$ruta/config.txt"

# si existe config.txt se carga para usar sus rutas
if [ -f "$config" ]; then
    source "$config"
fi

# si se interrumpe el inventario se sale de forma limpia
trap 'echo "inventario interrumpido"; exit 1' SIGINT SIGTERM

# si INVENTORY_DIR no existe en config se usa una carpeta local
if [ -z "$INVENTORY_DIR" ]; then
    INVENTORY_DIR="$ruta/inventarios"
fi

carpeta="$INVENTORY_DIR"

# se crea la carpeta donde se guardara el inventario
mkdir -p "$carpeta"

# se valida que la carpeta se haya creado correctamente
if [ "$?" -ne 0 ]; then
    echo "Error: no se pudo crear la carpeta '$carpeta'."
    exit 1
fi

# se guardan fechas para el reporte y para el nombre del archivo
fecha=$(date '+%Y-%m-%d %H:%M:%S')
fecha2=$(date '+%Y%m%d_%H%M%S')

# se indica donde se va a guardar el inventario
archivo="$carpeta/inventario_$fecha2.txt"

# se guardan datos basicos del sistema
host=$(hostname)
usuario=$(id -un)
kernel=$(uname -r)
nucleos=$(nproc 2>/dev/null)

# se valida si no se pudo obtener la cantidad de nucleos
if [ -z "$nucleos" ]; then
    nucleos="No disponible"
fi

# se obtiene el nombre del sistema operativo
if [ -f /etc/os-release ]; then
    sistema=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d "=" -f 2 | tr -d '"')
else
    sistema="Desconocido"
fi

# se obtiene el modelo del procesador
if [ -f /proc/cpuinfo ]; then
    procesador=$(grep -m 1 "model name" /proc/cpuinfo | cut -d ":" -f 2)
else
    procesador="Desconocido"
fi

# se obtiene informacion de memoria para el resumen
memoria_total=$(free -h 2>/dev/null | awk 'NR==2 {print $2}')
memoria_usada=$(free -h 2>/dev/null | awk 'NR==2 {print $3}')
memoria_disponible=$(free -h 2>/dev/null | awk 'NR==2 {print $7}')

# si no se pudo obtener memoria se deja como no disponible
if [ -z "$memoria_total" ]; then
    memoria_total="No disponible"
fi

if [ -z "$memoria_usada" ]; then
    memoria_usada="No disponible"
fi

if [ -z "$memoria_disponible" ]; then
    memoria_disponible="No disponible"
fi

# se obtiene el uso del disco raiz
disco=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}')

if [ -z "$disco" ]; then
    disco="No disponible"
fi

# se escribe el reporte principal
echo "inventario del sistema" > "$archivo"
echo "fecha: $fecha" >> "$archivo"
echo "host: $host" >> "$archivo"
echo "usuario: $usuario" >> "$archivo"
echo "" >> "$archivo"

# se guarda informacion del sistema operativo
echo "sistema operativo:" >> "$archivo"
echo "sistema: $sistema" >> "$archivo"
echo "kernel: $kernel" >> "$archivo"
echo "tiempo encendido:" >> "$archivo"
uptime -p >> "$archivo" 2>/dev/null
echo "" >> "$archivo"

# se guarda informacion del hardware
echo "hardware:" >> "$archivo"
echo "procesador:$procesador" >> "$archivo"
echo "nucleos cpu: $nucleos" >> "$archivo"
echo "memoria total: $memoria_total" >> "$archivo"
echo "memoria usada: $memoria_usada" >> "$archivo"
echo "memoria disponible: $memoria_disponible" >> "$archivo"
echo "uso del disco raiz: $disco" >> "$archivo"
echo "" >> "$archivo"

# se guarda la tabla completa de memoria
echo "detalle de memoria:" >> "$archivo"
free -h >> "$archivo" 2>/dev/null
echo "" >> "$archivo"

# se guarda informacion de discos y particiones
echo "discos y particiones:" >> "$archivo"
df -h >> "$archivo" 2>/dev/null
echo "" >> "$archivo"

# se guarda informacion de interfaces de red
echo "interfaces de red:" >> "$archivo"
if command -v ip > /dev/null 2>&1; then
    ip -o link show | awk -F': ' '{print $2}' >> "$archivo"
else
    echo "No disponible" >> "$archivo"
fi
echo "" >> "$archivo"

# se guarda informacion de usuarios normales
echo "usuarios del sistema:" >> "$archivo"
awk -F: '$3 >= 1000 && $3 < 65534 {print $1 " - UID: " $3 " - Shell: " $7}' /etc/passwd >> "$archivo"
echo "" >> "$archivo"

# se guarda informacion de servicios activos si existe systemctl
echo "servicios activos:" >> "$archivo"
if command -v systemctl > /dev/null 2>&1; then
    systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | awk '{print $1}' | head -15 >> "$archivo"
else
    echo "systemctl no disponible" >> "$archivo"
fi
echo "" >> "$archivo"

# se guarda informacion de programas instalados segun el gestor disponible
echo "software instalado:" >> "$archivo"
if command -v dpkg > /dev/null 2>&1; then
    dpkg -l | awk 'NR>5 {print $2}' | head -30 >> "$archivo"
elif command -v rpm > /dev/null 2>&1; then
    rpm -qa | head -30 >> "$archivo"
else
    echo "gestor de paquetes no disponible" >> "$archivo"
fi

# se registra en log si existe la funcion registrar de config.txt
if type registrar > /dev/null 2>&1; then
    registrar "inventario.sh" "Inventario generado en $archivo"
fi

# se envia resumen por telegram si esta configurado
if type enviar_telegram > /dev/null 2>&1; then
    enviar_telegram "Inventario generado" "Host: $host
CPU: $nucleos nucleos
Memoria total: $memoria_total
Memoria disponible: $memoria_disponible
Uso disco raiz: $disco
Reporte: $archivo" || true
fi

# se muestra el resultado final al usuario
if [ -f "$archivo" ]; then
    echo "Inventario generado correctamente."
    echo "Archivo: $archivo"
else
    echo "Error: no se pudo generar el inventario."
    exit 1
fi
