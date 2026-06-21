#!/bin/bash
# este script sirve para administrar usuarios del sistema
# permite crear eliminar modificar y listar usuarios
# el script no necesita abrirse como root, solo usa sudo cuando hace falta

# se busca el archivo config.txt en el mismo directorio donde se encuentra el proyecto
#Extrae el directorio en donde estamos situados
DIRECTORIO_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#Le da la ruta al script para que use el config.txt
CONFIG_TXT="$DIRECTORIO_BASE/config.txt"

#Importa el archivo de configuracion
if [ -f "$CONFIG_TXT" ]; then
	source "$CONFIG_TXT"
else
	echo "No se encuentra el archivo config.txt en $DIRECTORIO_BASE"
    exit 1
fi

# Validar que las variables de configuración se cargaron correctamente
validar_config || exit 1

# Captura de señales para asegurar salidas limpias
trap 'echo -e "\nScript de usuarios interrumpido por el administrador."; exit 1' SIGINT SIGTERM

permiso=""
# Si no somos root, usamos sudo en los comandos necesarios
if [ "$(id -u)" -ne 0 ]; then
	permiso="sudo"
	#"Comprueba que se tenga instalado Sudo
	if ! command -v sudo > /dev/null 2>&1; then
		echo "Se requiere tener 'sudo' instalado para gestionar usuarios."
		exit 1
	fi
fi

#Comprobar la existencia de un usuario
comprobar_usuario() {
	if id "$1" > /dev/null 2>&1; then
		return 0 # El usuario sí existe
	else
		return 1 # El usuario no existe
	fi
}

# MENÚ INTERACTIVO PRINCIPAL
#Arranca la variable en 0 para que entre al bucle
opcion=0

while [ "$opcion" != "4" ]; do
	echo "========================================="
	echo "       GESTIÓN DE USUARIOS DEL SISTEMA   "
    echo "========================================="
	echo "1. Crear un usuario nuevo"
	echo "2. Eliminar un usuario existente"
	echo "3. Modificar un usuario"
	echo "4. Salir"
	read -p "Selecciona la acción deseada: " opcion

	case $opcion in
	#Crear usuario
	    1)
			read -p "Indica el nombre del usuario a añadir: " usuario
			if [ -z "$usuario" ]; then
				echo "Error: El nombre de usuario no puede estar vacío."
				continue
			fi

			if comprobar_usuario "$usuario"; then
				echo "Error: El usuario '$usuario' ya existe en el sistema."
			else
                # Se crea usuario con directorio home y bash por defecto
                $permiso useradd -m -s /bin/bash "$usuario"
                
                if [ $? -eq 0 ]; then
                    echo "Asignación de contraseña para el usuario $usuario:"
                    $permiso passwd "$usuario"
                    
                    registrar "usuarios" "Se ha creado exitosamente el usuario: $usuario"
                    enviar_telegram "Usuario Creado" "Se ha añadido el usuario <b>$usuario</b> al sistema."
                    echo "Usuario '$usuario' creado correctamente."
                else
                    echo "Error grave: No se pudo crear al usuario."
                fi
            fi
            ;;

        # ---------------------------------------------------------
        # OPCIÓN 2: ELIMINAR USUARIO
        # ---------------------------------------------------------
        2)
            read -p "Indica el nombre del usuario a eliminar: " usuario
            
            if [ -z "$usuario" ]; then
                continue
            fi

            if comprobar_usuario "$usuario"; then
                read -p "¿Deseas eliminar también su directorio home? [s/n]: " confirmar
                
                if [[ "$confirmar" == "s" || "$confirmar" == "S" ]]; then
                    $permiso userdel -r "$usuario"
                else
                    $permiso userdel "$usuario"
                fi

                if [ $? -eq 0 ]; then
                    echo "El usuario '$usuario' se ha eliminado correctamente."
                    registrar "usuarios" "Se ha eliminado el usuario: $usuario"
                    enviar_telegram "Usuario Eliminado" "El usuario <b>$usuario</b> ha sido dado de baja del servidor."
                else
                    echo "Error: Ocurrió un problema al intentar eliminar al usuario."
                fi
            else
                echo "Error: El usuario '$usuario' no existe."
            fi
            ;;

        # ---------------------------------------------------------
        # OPCIÓN 3: MODIFICAR USUARIO
        # ---------------------------------------------------------
        3)
            read -p "Indica el nombre del usuario a modificar: " usuario
            
            if [ -z "$usuario" ]; then 
                continue 
            fi

            if comprobar_usuario "$usuario"; then
                opcion2=0
                # Submenú iterativo para realizar varias modificaciones al mismo usuario
                while [ "$opcion2" != "5" ]; do
                    echo "-----------------------------------------"
                    echo "      Modificando al usuario: $usuario   "
                    echo "-----------------------------------------"
                    echo "1. Cambiar contraseña"
                    echo "2. Cambiar grupo principal"
                    echo "3. Añadir a grupo secundario"
                    echo "4. Cambiar shell (intérprete de comandos)"
                    echo "5. Volver al menú principal"
                    read -p "Selecciona qué parámetro quieres modificar: " opcion2

                    case $opcion2 in
                        1)
                            $permiso passwd "$usuario"
                            registrar "usuarios" "Modificación: Cambio de contraseña para $usuario"
                            enviar_telegram "Usuario Modificado" "Se ha actualizado la contraseña del usuario <b>$usuario</b>."
                            ;;
                        2)
                            read -p "Introduce el nombre del nuevo grupo principal: " grupo
                            $permiso usermod -g "$grupo" "$usuario"
                            if [ $? -eq 0 ]; then
                                registrar "usuarios" "Modificación: Grupo principal de $usuario cambiado a $grupo"
                                enviar_telegram "Usuario Modificado" "Se cambió el grupo principal de <b>$usuario</b> a $grupo."
                            fi
                            ;;
                        3)
                            read -p "Introduce el nombre del grupo secundario: " grupo
                            $permiso usermod -aG "$grupo" "$usuario"
                            if [ $? -eq 0 ]; then
                                registrar "usuarios" "Modificación: Se añadió $usuario al grupo secundario $grupo"
                                enviar_telegram "Usuario Modificado" "Se añadió a <b>$usuario</b> al grupo secundario $grupo."
                            fi
                            ;;
                        4)
                            read -p "Ruta del nuevo shell (ej. /bin/bash): " shell
                            if [ -x "$shell" ]; then
                                $permiso usermod -s "$shell" "$usuario"
                                registrar "usuarios" "Modificación: Shell de $usuario cambiado a $shell"
                                enviar_telegram "Usuario Modificado" "El shell de <b>$usuario</b> cambió a $shell."
                            else
                                echo "Error: El shell proporcionado '$shell' no existe o no cuenta con permisos de ejecución."
                            fi
                            ;;
                        5)
                            echo "Regresando al menú principal..."
                            ;;
                        *)
                            echo "Opción inválida en el submenú."
                            ;;
                    esac
                done
            else
                echo "Error: El usuario '$usuario' no existe en el sistema."
            fi
            ;;

        # ---------------------------------------------------------
        # OPCIÓN 4: SALIR
        # ---------------------------------------------------------
        4)
            echo "Saliendo del gestor de usuarios de forma limpia..."
            exit 0
            ;;
        *)
            echo "Opción no válida. Por favor, selecciona un número del 1 al 4."
            ;;
    esac
done

echo "proceso finalizado"
