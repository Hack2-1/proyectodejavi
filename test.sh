#!/bin/bash
# test.sh — Pruebas seguras del sistema de gestión
# Uso: ./test.sh
# Valida archivos, sintaxis y módulos que no requieren privilegios

# 1. VARIABLES DE TRABAJO
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTORNO_PRUEBA=$(mktemp -d)
TOTAL_PRUEBAS=0
PRUEBAS_PASADAS=0
PRUEBAS_FALLIDAS=0

export LOG_DIR="${ENTORNO_PRUEBA}/logs"
export BACKUP_DIR="${ENTORNO_PRUEBA}/respaldos"
export REPORTS_DIR="${ENTORNO_PRUEBA}/reportes"
export INVENTORY_DIR="${ENTORNO_PRUEBA}/inventarios"
export SCRIPTS_DIR="$SCRIPT_DIR"
export TELEGRAM_ENABLED=false

trap 'rm -rf "$ENTORNO_PRUEBA"' EXIT SIGINT SIGTERM

# ============================================================================
# FUNCIONES
# ============================================================================

# 2. Registrar resultado
resultado_prueba() {
    local nombre="$1"
    local codigo="$2"

    TOTAL_PRUEBAS=$((TOTAL_PRUEBAS + 1))

    if [ "$codigo" -eq 0 ]; then
        printf "✓ %-52s [PASÓ]\n" "$nombre"
        PRUEBAS_PASADAS=$((PRUEBAS_PASADAS + 1))
    else
        printf "✗ %-52s [FALLÓ]\n" "$nombre"
        PRUEBAS_FALLIDAS=$((PRUEBAS_FALLIDAS + 1))
    fi
}

# 3. Validar archivos y sintaxis
probar_archivos() {
    local archivos=(config.txt configurar-telegram.sh diagnostico.sh usuarios.sh respaldo.sh monitoreo.sh servicios.sh remoto.sh red.sh inventario.sh)
    local archivo

    for archivo in "${archivos[@]}"; do
        [ -f "${SCRIPT_DIR}/${archivo}" ]
        resultado_prueba "Existe $archivo" "$?"

        bash -n "${SCRIPT_DIR}/${archivo}" 2>/dev/null
        resultado_prueba "Sintaxis de $archivo" "$?"
    done
}

# 4. Validar identificadores Bash en ASCII
probar_identificadores_ascii() {
    if LC_ALL=C grep -nE \
        '(^|[[:space:]])(local|declare|readonly|export|read)[^#]*[^[:ascii:][:space:]]+[=[:space:]]' \
        "${SCRIPT_DIR}"/*.sh "${SCRIPT_DIR}/config.txt" >/dev/null 2>&1; then
        resultado_prueba "Identificadores Bash usan caracteres ASCII" 1
    else
        resultado_prueba "Identificadores Bash usan caracteres ASCII" 0
    fi
}

# 5. Probar compatibilidad del instalador con Zorin OS
probar_instalador_zorin() {
    local os_release="${ENTORNO_PRUEBA}/zorin-os-release"
    local bin_setup="${ENTORNO_PRUEBA}/setup-bin"

    mkdir -p "$bin_setup"
    {
        echo 'ID=zorin'
        echo 'ID_LIKE="ubuntu debian"'
        echo 'PRETTY_NAME="Zorin OS 18 Pro"'
    } > "$os_release"

    for comando in bash awk sed tar find df free ps curl ping ssh scp timeout systemctl; do
        if command -v "$comando" &>/dev/null; then
            ln -s "$(command -v "$comando")" "${bin_setup}/${comando}"
        else
            cat > "${bin_setup}/${comando}" << 'EOF'
#!/bin/bash
exit 0
EOF
            chmod +x "${bin_setup}/${comando}"
        fi
    done

    PATH="${bin_setup}:$PATH" OS_RELEASE_FILE="$os_release" \
        "${SCRIPT_DIR}/setup.sh" --check >/dev/null 2>&1
    resultado_prueba "Compatibilidad de setup.sh con Zorin OS" "$?"
}

# 6. Probar carga externa de credenciales
probar_credenciales_externas() {
    local credenciales="${ENTORNO_PRUEBA}/telegram.env"

    {
        echo 'TELEGRAM_ENABLED=true'
        echo 'TELEGRAM_BOT_TOKEN="token_de_prueba"'
        echo 'TELEGRAM_CHAT_ID="123456"'
    } > "$credenciales"

    CREDENTIALS_FILE="$credenciales" bash -c \
        'source "$1/config.txt"; [ "$TELEGRAM_ENABLED" = true ] &&
         [ "$TELEGRAM_BOT_TOKEN" = token_de_prueba ] &&
         [ "$TELEGRAM_CHAT_ID" = 123456 ]' _ "$SCRIPT_DIR"
    resultado_prueba "Carga segura de credenciales externas" "$?"
}

# 7. Probar ayudas sin efectos secundarios
probar_ayudas() {
    "${SCRIPT_DIR}/monitoreo.sh" -h >/dev/null 2>&1
    resultado_prueba "Ayuda de monitoreo.sh" "$?"

    "${SCRIPT_DIR}/red.sh" -h >/dev/null 2>&1
    resultado_prueba "Ayuda de red.sh" "$?"
}

# 8. Probar módulos locales
probar_ejecucion_local() {
    mkdir -p "${ENTORNO_PRUEBA}/origen"
    echo "archivo de prueba" > "${ENTORNO_PRUEBA}/origen/dato.txt"

    "${SCRIPT_DIR}/monitoreo.sh" >/dev/null 2>&1
    resultado_prueba "Ejecución local de monitoreo.sh" "$?"

    "${SCRIPT_DIR}/inventario.sh" >/dev/null 2>&1
    resultado_prueba "Ejecución local de inventario.sh" "$?"

    "${SCRIPT_DIR}/respaldo.sh" "${ENTORNO_PRUEBA}/origen" >/dev/null 2>&1
    resultado_prueba "Creación y verificación de respaldo" "$?"
}

# 9. Probar clasificación de red con comandos simulados
probar_clasificacion_red() {
    local bin_prueba="${ENTORNO_PRUEBA}/bin"
    local hosts_prueba="${ENTORNO_PRUEBA}/hosts.txt"
    local salida_red="${ENTORNO_PRUEBA}/red.txt"

    mkdir -p "$bin_prueba"

    cat > "${bin_prueba}/ping" << 'EOF'
#!/bin/bash
host="${@: -1}"
[ "$host" != "host-caido" ]
EOF

    cat > "${bin_prueba}/nc" << 'EOF'
#!/bin/bash
host="${@: -2:1}"
puerto="${@: -1}"

if [ "$host" = "host-activo" ]; then
    exit 0
fi

[ "$host" = "host-parcial" ] && [ "$puerto" = "22" ]
EOF

    cat > "${bin_prueba}/timeout" << 'EOF'
#!/bin/bash
shift
exec "$@"
EOF

    chmod +x "${bin_prueba}/ping" "${bin_prueba}/nc" "${bin_prueba}/timeout"
    printf '%s\n' host-activo host-parcial host-caido > "$hosts_prueba"

    PATH="${bin_prueba}:$PATH" "${SCRIPT_DIR}/red.sh" \
        -f "$hosts_prueba" -p "22 80" > "$salida_red" 2>&1

    grep -q "Hosts Accesibles:.*1" "$salida_red" &&
        grep -q "Hosts Parcialmente Accesibles:.*1" "$salida_red" &&
        grep -q "Hosts sin Respuesta:.*1" "$salida_red" &&
        grep -q "host-parcial - puertos cerrados: 80" "$salida_red"
    resultado_prueba "Clasificación y detalle de red.sh" "$?"
}

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================

echo "╔════════════════════════════════════════╗"
echo "║       PRUEBAS SEGURAS DEL SISTEMA       ║"
echo "╚════════════════════════════════════════╝"
echo ""

probar_archivos
probar_identificadores_ascii
probar_instalador_zorin
probar_credenciales_externas
probar_ayudas
probar_ejecucion_local
probar_clasificacion_red

echo ""
echo "Total: $TOTAL_PRUEBAS | Pasaron: $PRUEBAS_PASADAS | Fallaron: $PRUEBAS_FALLIDAS"

if [ "$PRUEBAS_FALLIDAS" -gt 0 ]; then
    exit 1
fi

echo "✓ Todas las pruebas seguras pasaron"
exit 0
