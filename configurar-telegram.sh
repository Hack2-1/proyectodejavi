#!/bin/bash
# este script configura las credenciales de telegram
# guarda el token y chat id fuera del repositorio

# se define donde se guardaran las credenciales
# se usa una ruta del usuario para no necesitar root
archivo="${CREDENTIALS_FILE:-$HOME/.config/sistema-servicios/telegram.env}"

# se valida que exista curl
if ! command -v curl > /dev/null 2>&1; then
    echo "Error: curl no esta instalado."
    exit 1
fi

# si se interrumpe la configuracion se sale de forma limpia
trap 'echo "configuracion interrumpida"; exit 1' SIGINT SIGTERM

echo "configuracion de telegram"
echo "el token no se guardara dentro del repositorio"

# se piden los datos al usuario
read -s -p "Token del bot: " token
echo ""
read -p "Chat ID: " chat

# se limpian espacios que se hayan pegado por error
token=$(printf '%s' "$token" | tr -d '[:space:]')
chat=$(printf '%s' "$chat" | tr -d '[:space:]')

# se valida que no esten vacios
if [ -z "$token" ] || [ -z "$chat" ]; then
    echo "Error: token y chat id son obligatorios."
    exit 1
fi

# se prueba el bot con telegram
echo "probando conexion con telegram..."
respuesta=$(curl --silent --show-error --max-time 15 \
    -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d "chat_id=${chat}" \
    -d "text=Telegram configurado correctamente")

echo "$respuesta" | grep -q '"ok":true'

if [ "$?" -ne 0 ]; then
    echo "Error: telegram no acepto los datos."
    exit 1
fi

# se crea la carpeta para las credenciales
mkdir -p "$(dirname "$archivo")"

if [ "$?" -ne 0 ]; then
    echo "Error: no se pudo crear la carpeta de credenciales."
    exit 1
fi

# se guardan las credenciales
{
    echo "TELEGRAM_ENABLED=true"
    echo "TELEGRAM_BOT_TOKEN='$token'"
    echo "TELEGRAM_CHAT_ID='$chat'"
} > "$archivo"

chmod 600 "$archivo"

echo "telegram configurado correctamente"
echo "archivo: $archivo"
