#!/bin/bash
# configurar-telegram.sh — Configuración segura del bot de Telegram
# Uso: sudo ./configurar-telegram.sh
# Guarda credenciales fuera del repositorio y envía un mensaje de prueba

# 1. VARIABLES Y VALIDACIONES
CREDENTIALS_FILE="${CREDENTIALS_FILE:-/etc/sistema-servicios/telegram.env}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Ejecuta este configurador con sudo"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo "Error: curl no está instalado"
    exit 1
fi

trap 'echo ""; echo "Configuración interrumpida"; exit 1' SIGINT SIGTERM

# 2. SOLICITAR CREDENCIALES
echo "╔════════════════════════════════════════╗"
echo "║      CONFIGURACIÓN SEGURA TELEGRAM      ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "El token no se mostrará ni se guardará dentro del repositorio."
echo ""

read -rsp "Token nuevo del bot: " TELEGRAM_BOT_TOKEN
echo ""
read -rp "Chat ID: " TELEGRAM_CHAT_ID

# Eliminar espacios, retornos de carro y saltos de línea pegados por accidente
TELEGRAM_BOT_TOKEN=$(printf '%s' "$TELEGRAM_BOT_TOKEN" | tr -d '[:space:]')
TELEGRAM_CHAT_ID=$(printf '%s' "$TELEGRAM_CHAT_ID" | tr -d '[:space:]')

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "Error: El token y el Chat ID son obligatorios"
    exit 1
fi

TOKEN_ID="${TELEGRAM_BOT_TOKEN%%:*}"
TOKEN_SECRETO="${TELEGRAM_BOT_TOKEN#*:}"

if [ "$TOKEN_ID" = "$TELEGRAM_BOT_TOKEN" ] ||
   ! [[ "$TOKEN_ID" =~ ^[0-9]+$ ]] ||
   ! [[ "$TOKEN_SECRETO" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "Error: El formato del token no es válido"
    echo "Debe tener el formato: números:letras_y_números"
    echo "Copia únicamente el token entregado por @BotFather"
    unset TELEGRAM_BOT_TOKEN TOKEN_ID TOKEN_SECRETO
    exit 1
fi

if ! [[ "$TELEGRAM_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
    echo "Error: El Chat ID debe ser numérico"
    exit 1
fi

# 3. VALIDAR TOKEN CON TELEGRAM
echo "[*] Validando el bot..."
if ! curl --fail --silent --show-error --max-time 15 \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" >/dev/null; then
    echo "Error: Telegram rechazó el token o no hay conexión"
    exit 1
fi

# 4. GUARDAR FUERA DEL REPOSITORIO
install -d -m 750 "$(dirname "$CREDENTIALS_FILE")"
umask 077
{
    printf 'TELEGRAM_ENABLED=true\n'
    printf 'TELEGRAM_BOT_TOKEN=%q\n' "$TELEGRAM_BOT_TOKEN"
    printf 'TELEGRAM_CHAT_ID=%q\n' "$TELEGRAM_CHAT_ID"
} > "$CREDENTIALS_FILE"

chmod 600 "$CREDENTIALS_FILE"

if getent group sistema-servicios >/dev/null; then
    chown root:sistema-servicios "$(dirname "$CREDENTIALS_FILE")"
    chmod 750 "$(dirname "$CREDENTIALS_FILE")"
    chown root:sistema-servicios "$CREDENTIALS_FILE"
    chmod 640 "$CREDENTIALS_FILE"
fi

# 5. ENVIAR MENSAJE DE PRUEBA
echo "[*] Enviando mensaje de prueba..."
if ! curl --fail --silent --show-error --max-time 15 \
    -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=Configuración completada en Zorin OS" >/dev/null; then
    echo "Error: Las credenciales se guardaron, pero no se pudo enviar el mensaje"
    exit 1
fi

unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
unset TOKEN_ID TOKEN_SECRETO

echo "✓ Telegram configurado correctamente"
echo "✓ Credenciales guardadas en: $CREDENTIALS_FILE"
echo "Nota: Cierra sesión y vuelve a entrar antes de ejecutar los scripts sin sudo"
exit 0
