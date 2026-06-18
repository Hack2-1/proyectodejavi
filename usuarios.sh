#!/bin/bash
# este script sirve para administrar usuarios del sistema
# permite crear eliminar modificar y listar usuarios
# el script no necesita abrirse como root, solo usa sudo cuando hace falta

# se busca el archivo config.txt en la misma carpeta
ruta="$(cd "$(dirname "$0")" && pwd)"
config="$ruta/config.txt"

# se valida si existe config.txt para usar la carpeta de logs
if [ -f "$config" ]; then
    source "$config"
else
    LOG_DIR="$ruta/logs"
fi

# se crea la carpeta de logs
mkdir -p "$LOG_DIR"

if [ "$?" -ne 0 ]; then
    echo "Error: no se pudo crear la carpeta de logs."
    exit 1
fi

# si el usuario interrumpe el script se muestra mensaje
trap 'echo "script de usuarios interrumpido"; exit 1' SIGINT SIGTERM

# si no somos root se usara sudo solo en los comandos necesarios
permiso=""
if [ "$(id -u)" -ne 0 ]; then
    permiso="sudo"
fi

# se muestra el menu de opciones
echo "gestion de usuarios"
echo "1. crear usuario"
echo "2. eliminar usuario"
echo "3. modificar shell de usuario"
echo "4. listar usuarios"
read -p "Elige una opcion: " opcion

# opcion 1 crear usuario
if [ "$opcion" = "1" ]; then
    read -p "Nombre del usuario: " usuario

    # se valida que exista sudo si no somos root
    if [ -n "$permiso" ] && ! command -v sudo > /dev/null 2>&1; then
        echo "Error: para crear usuarios necesitas sudo instalado."
        exit 1
    fi

    # se valida que el nombre no este vacio
    if [ -z "$usuario" ]; then
        echo "Error: el nombre del usuario no puede estar vacio."
        exit 1
    fi

    # se valida que el usuario no exista
    if id "$usuario" > /dev/null 2>&1; then
        echo "Error: el usuario '$usuario' ya existe."
        exit 1
    fi

    # se crea el usuario con carpeta home y bash
    $permiso useradd -m -s /bin/bash "$usuario"

    if [ "$?" -ne 0 ]; then
        echo "Error: no se pudo crear el usuario."
        exit 1
    fi

    # se asigna la contrasena de forma interactiva
    $permiso passwd "$usuario"

    if [ "$?" -ne 0 ]; then
        echo "Error: no se pudo asignar la contrasena."
        exit 1
    fi

    echo "Usuario '$usuario' creado correctamente."
    echo "$(date '+%Y-%m-%d %H:%M:%S') usuario creado: $usuario" >> "$LOG_DIR/usuarios.log"
    enviar_telegram "Usuario creado" "Usuario: $usuario" || true

# opcion 2 eliminar usuario
elif [ "$opcion" = "2" ]; then
    read -p "Usuario a eliminar: " usuario

    # se valida que exista sudo si no somos root
    if [ -n "$permiso" ] && ! command -v sudo > /dev/null 2>&1; then
        echo "Error: para eliminar usuarios necesitas sudo instalado."
        exit 1
    fi

    # se valida que el usuario exista
    if ! id "$usuario" > /dev/null 2>&1; then
        echo "Error: el usuario '$usuario' no existe."
        exit 1
    fi

    read -p "Eliminar tambien su carpeta home? [s/n]: " confirmar

    if [ "$confirmar" = "s" ] || [ "$confirmar" = "S" ]; then
        $permiso userdel -r "$usuario"
    else
        $permiso userdel "$usuario"
    fi

    if [ "$?" -ne 0 ]; then
        echo "Error: no se pudo eliminar el usuario."
        exit 1
    fi

    echo "Usuario '$usuario' eliminado correctamente."
    echo "$(date '+%Y-%m-%d %H:%M:%S') usuario eliminado: $usuario" >> "$LOG_DIR/usuarios.log"
    enviar_telegram "Usuario eliminado" "Usuario: $usuario" || true

# opcion 3 modificar shell
elif [ "$opcion" = "3" ]; then
    read -p "Usuario a modificar: " usuario

    # se valida que exista sudo si no somos root
    if [ -n "$permiso" ] && ! command -v sudo > /dev/null 2>&1; then
        echo "Error: para modificar usuarios necesitas sudo instalado."
        exit 1
    fi

    # se valida que el usuario exista
    if ! id "$usuario" > /dev/null 2>&1; then
        echo "Error: el usuario '$usuario' no existe."
        exit 1
    fi

    read -p "Nuevo shell, ejemplo /bin/bash: " shell

    # se valida que el shell exista
    if [ ! -x "$shell" ]; then
        echo "Error: el shell '$shell' no existe."
        exit 1
    fi

    $permiso usermod -s "$shell" "$usuario"

    if [ "$?" -ne 0 ]; then
        echo "Error: no se pudo modificar el usuario."
        exit 1
    fi

    echo "Shell cambiado correctamente."
    echo "$(date '+%Y-%m-%d %H:%M:%S') shell cambiado: $usuario $shell" >> "$LOG_DIR/usuarios.log"
    enviar_telegram "Usuario modificado" "Usuario: $usuario
Nuevo shell: $shell" || true

# opcion 4 listar usuarios
elif [ "$opcion" = "4" ]; then
    echo "usuarios del sistema:"
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1 " - UID: " $3 " - Shell: " $7}' /etc/passwd

else
    echo "Opcion no valida."
    exit 1
fi

echo "proceso finalizado"
