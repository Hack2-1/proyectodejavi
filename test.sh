#!/bin/bash
# este script prueba que los archivos principales funcionen
# las pruebas son seguras y usan carpetas temporales

# se crean variables para las pruebas
ruta="$(cd "$(dirname "$0")" && pwd)"
prueba=$(mktemp -d)
total=0
pasadas=0
falladas=0

# se exportan rutas temporales para no usar carpetas reales del sistema
export LOG_DIR="$prueba/logs"
export BACKUP_DIR="$prueba/respaldos"
export REPORTS_DIR="$prueba/reportes"
export INVENTORY_DIR="$prueba/inventarios"
export SCRIPTS_DIR="$ruta"
export TELEGRAM_ENABLED=false

# esta funcion guarda el resultado de cada prueba
resultado() {
    nombre="$1"
    codigo="$2"

    total=$((total + 1))

    if [ "$codigo" -eq 0 ]; then
        echo "[OK] $nombre"
        pasadas=$((pasadas + 1))
    else
        echo "[ERROR] $nombre"
        falladas=$((falladas + 1))
    fi
}

# se eliminan archivos temporales al final
limpiar() {
    rm -rf "$prueba"
}

trap limpiar EXIT

echo "pruebas del proyecto"

# se valida que existan los archivos principales
archivos="config.txt configurar-telegram.sh diagnostico.sh usuarios.sh respaldo.sh monitoreo.sh servicios.sh remoto.sh red.sh inventario.sh setup.sh"

for archivo in $archivos
do
    [ -f "$ruta/$archivo" ]
    resultado "existe $archivo" "$?"

    bash -n "$ruta/$archivo" 2>/dev/null
    resultado "sintaxis $archivo" "$?"
done

# se prueba setup en modo check usando un os-release temporal
archivo="$prueba/os-release"
carpeta="$prueba/setup-bin"
{
    echo "ID=zorin"
    echo "ID_LIKE='ubuntu debian'"
    echo "PRETTY_NAME='Zorin OS de prueba'"
} > "$archivo"

mkdir -p "$carpeta"

# se crean comandos falsos si en este entorno no existen
for comando in bash awk sed tar find df free ps curl ping ssh scp timeout systemctl
do
    if command -v "$comando" > /dev/null 2>&1; then
        ln -s "$(command -v "$comando")" "$carpeta/$comando"
    else
        {
            echo "#!/bin/bash"
            echo "exit 0"
        } > "$carpeta/$comando"
        chmod +x "$carpeta/$comando"
    fi
done

PATH="$carpeta:$PATH" OS_RELEASE_FILE="$archivo" "$ruta/setup.sh" --check > /dev/null 2>&1
resultado "setup en modo check" "$?"

# se prueba la ayuda de monitoreo
"$ruta/monitoreo.sh" -h > /dev/null 2>&1
resultado "ayuda monitoreo.sh" "$?"

# se prueba la ayuda de red
"$ruta/red.sh" -h > /dev/null 2>&1
resultado "ayuda red.sh" "$?"

# se prueba diagnostico
"$ruta/diagnostico.sh" > /dev/null 2>&1
resultado "ejecucion diagnostico.sh" "$?"

# se prueba inventario
"$ruta/inventario.sh" > /dev/null 2>&1
resultado "ejecucion inventario.sh" "$?"

# se prueba respaldo con un directorio temporal
mkdir -p "$prueba/origen"
echo "archivo de prueba" > "$prueba/origen/dato.txt"

"$ruta/respaldo.sh" "$prueba/origen" > /dev/null 2>&1
resultado "ejecucion respaldo.sh" "$?"

# se prueba red con comandos simulados para no depender de internet
carpeta="$prueba/bin"
hosts="$prueba/hosts.txt"
salida="$prueba/red.txt"
mkdir -p "$carpeta"

cat > "$carpeta/ping" << 'EOF'
#!/bin/bash
host="${@: -1}"
[ "$host" != "host-caido" ]
EOF

cat > "$carpeta/nc" << 'EOF'
#!/bin/bash
host="${@: -2:1}"
puerto="${@: -1}"
[ "$host" = "host-activo" ] || { [ "$host" = "host-parcial" ] && [ "$puerto" = "22" ]; }
EOF

cat > "$carpeta/timeout" << 'EOF'
#!/bin/bash
shift
exec "$@"
EOF

chmod +x "$carpeta/ping" "$carpeta/nc" "$carpeta/timeout"
printf '%s\n' host-activo host-parcial host-caido > "$hosts"

PATH="$carpeta:$PATH" "$ruta/red.sh" -f "$hosts" -p "22 80" > "$salida" 2>&1
grep -q "host: host-activo" "$salida" && grep -q "host: host-caido" "$salida"
resultado "ejecucion red.sh con hosts de prueba" "$?"

echo ""
echo "total: $total"
echo "pasadas: $pasadas"
echo "falladas: $falladas"

if [ "$falladas" -gt 0 ]; then
    exit 1
fi

echo "todas las pruebas pasaron"
exit 0
