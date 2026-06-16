#!/bin/bash
# usuarios.sh — Gestión de usuarios del sistema
# Uso: ./usuarios.sh
# Permite crear, eliminar y modificar usuarios de forma interactiva

# 1. INICIALIZACIÓN Y VALIDACIONES
CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: No se encontró config.txt en el directorio del script"
    exit 1
fi

source "$CONFIG_FILE"
validar_config || exit 1

# 2. VALIDAR PERMISOS DE ROOT
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Este script debe ejecutarse como root"
    exit 1
fi

# 3. CREAR DIRECTORIO DE LOGS SI NO EXISTE
mkdir -p "$LOG_DIR" 2>/dev/null || {
    echo "Error: No se pudo crear el directorio de logs: $LOG_DIR"
    exit 1
}

# 4. TRAP PARA MANEJO LIMPIO DE SEÑALES
trap 'echo "Script interrumpido"; exit 1' SIGINT SIGTERM

# ============================================================================
# FUNCIONES
# ============================================================================

# 5. Crear usuario
crear_usuario() {
    local usuario="$1"
    local contrasena="$2"
    local shell="${3:-/bin/bash}"

    # Validar formato antes de consultar el sistema
    if ! [[ "$usuario" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        echo "Error: Nombre de usuario no válido"
        echo "Usa minúsculas, números, guion o guion bajo (máximo 32 caracteres)"
        return 1
    fi

    # Validar que el usuario no existe
    if id "$usuario" &>/dev/null; then
        echo "Error: El usuario '$usuario' ya existe"
        registrar "usuarios.sh" "FALLO: Intento de crear usuario existente: $usuario"
        return 1
    fi

    if [ "${#contrasena}" -lt 8 ]; then
        echo "Error: La contraseña debe tener al menos 8 caracteres"
        return 1
    fi

    if [ ! -x "$shell" ]; then
        echo "Error: El shell no existe o no es ejecutable: $shell"
        return 1
    fi

    # Crear el usuario y asignar la contraseña sin exponerla en argumentos
    if useradd -m -s "$shell" "$usuario" 2>/dev/null; then
        if ! chpasswd <<< "${usuario}:${contrasena}"; then
            userdel -r "$usuario" 2>/dev/null
            echo "Error: No se pudo asignar la contraseña; usuario revertido"
            registrar "usuarios.sh" "FALLO: Contraseña no asignada, usuario $usuario revertido"
            return 1
        fi

        echo "✓ Usuario '$usuario' creado exitosamente"
        registrar "usuarios.sh" "CREADO: Usuario $usuario con shell $shell"
        enviar_telegram "Nuevo Usuario" "Usuario <b>$usuario</b> ha sido creado en el sistema" || true
        return 0
    else
        echo "Error: No se pudo crear el usuario '$usuario'"
        registrar "usuarios.sh" "FALLO: No se pudo crear usuario $usuario"
        return 1
    fi
}

# 6. Eliminar usuario
eliminar_usuario() {
    local usuario="$1"

    # Validar que el usuario existe
    if ! id "$usuario" &>/dev/null; then
        echo "Error: El usuario '$usuario' no existe"
        registrar "usuarios.sh" "FALLO: Intento de eliminar usuario inexistente: $usuario"
        return 1
    fi

    # Preguntar confirmación
    read -p "¿Eliminar el directorio home de $usuario también? (s/n): " -r confirmacion

    if [[ "$confirmacion" =~ ^[Ss]$ ]]; then
        userdel -r "$usuario" 2>/dev/null
    else
        userdel "$usuario" 2>/dev/null
    fi

    if [ $? -eq 0 ]; then
        echo "✓ Usuario '$usuario' eliminado exitosamente"
        registrar "usuarios.sh" "ELIMINADO: Usuario $usuario"
        enviar_telegram "Usuario Eliminado" "Usuario <b>$usuario</b> ha sido eliminado del sistema" || true
        return 0
    else
        echo "Error: No se pudo eliminar el usuario '$usuario'"
        registrar "usuarios.sh" "FALLO: No se pudo eliminar usuario $usuario"
        return 1
    fi
}

# 7. Modificar usuario
modificar_usuario() {
    local usuario="$1"
    local nuevo_shell="$2"

    # Validar que el usuario existe
    if ! id "$usuario" &>/dev/null; then
        echo "Error: El usuario '$usuario' no existe"
        registrar "usuarios.sh" "FALLO: Intento de modificar usuario inexistente: $usuario"
        return 1
    fi

    if [ ! -x "$nuevo_shell" ]; then
        echo "Error: El shell no existe o no es ejecutable: $nuevo_shell"
        return 1
    fi

    # Cambiar shell si se proporciona
    if [ -n "$nuevo_shell" ]; then
        usermod -s "$nuevo_shell" "$usuario" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✓ Shell de '$usuario' cambiado a '$nuevo_shell'"
            registrar "usuarios.sh" "MODIFICADO: Shell de usuario $usuario a $nuevo_shell"
            enviar_telegram "Usuario Modificado" "Usuario <b>$usuario</b> ha sido modificado (shell: $nuevo_shell)" || true
            return 0
        else
            echo "Error: No se pudo modificar el usuario '$usuario'"
            registrar "usuarios.sh" "FALLO: No se pudo modificar usuario $usuario"
            return 1
        fi
    fi
}

# 8. Listar usuarios
listar_usuarios() {
    echo ""
    echo "========== USUARIOS DEL SISTEMA =========="
    awk -F: '$3 >= 1000 && $3 < 60000 {
        printf "%-15s UID: %-5s GID: %-5s Shell: %s\n", $1, $3, $4, $7
    }' /etc/passwd
    echo "=========================================="
    echo ""
}

# 9. Mostrar menú interactivo
mostrar_menu() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   GESTOR DE USUARIOS DEL SISTEMA       ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ 1. Crear nuevo usuario                 ║"
    echo "║ 2. Eliminar usuario                    ║"
    echo "║ 3. Modificar usuario (cambiar shell)   ║"
    echo "║ 4. Listar usuarios                     ║"
    echo "║ 5. Salir                               ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
}

# ============================================================================
# MENÚ PRINCIPAL
# ============================================================================

registrar "usuarios.sh" "INICIO: Script usuarios.sh iniciado por $(whoami)"

while true; do
    mostrar_menu
    read -p "Selecciona una opción [1-5]: " opcion

    case "$opcion" in
        1)
            echo ""
            read -p "Nombre de usuario: " usuario
            read -rsp "Contraseña: " contrasena
            echo ""
            read -rsp "Confirmar contraseña: " confirmar_contrasena
            echo ""

            if [ "$contrasena" != "$confirmar_contrasena" ]; then
                echo "Error: Las contraseñas no coinciden"
                unset contrasena confirmar_contrasena
                continue
            fi

            read -p "Shell (/bin/bash por defecto): " shell
            shell="${shell:-/bin/bash}"
            crear_usuario "$usuario" "$contrasena" "$shell"
            unset contrasena confirmar_contrasena
            ;;
        2)
            echo ""
            read -p "Nombre de usuario a eliminar: " usuario
            eliminar_usuario "$usuario"
            ;;
        3)
            echo ""
            read -p "Nombre de usuario a modificar: " usuario
            read -p "Nuevo shell (/bin/bash, /bin/sh, /bin/false, etc): " nuevo_shell
            modificar_usuario "$usuario" "$nuevo_shell"
            ;;
        4)
            listar_usuarios
            ;;
        5)
            echo "Saliendo..."
            registrar "usuarios.sh" "CIERRE: Script usuarios.sh finalizado"
            exit 0
            ;;
        *)
            echo "Opción no válida. Intenta de nuevo."
            ;;
    esac

    read -p "Presiona Enter para continuar..."
done
