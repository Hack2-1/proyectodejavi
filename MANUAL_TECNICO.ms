.ds FAM H
.nr PO 0.65i
.nr LL 7.1i
.nr HM 0.45i
.nr FM 0.45i
.ps 12
.vs 16
.ce 100
.ps 20
.B "Manual Tecnico"
.sp 0.3
.ps 16
.B "Sistema Automatizado de Servicios con Bash"
.sp 0.3
.ps 12
Proyecto Integrador PPS
.br
Ingenieria en Ciberseguridad e Infraestructura de Computo
.br
Programacion para Administracion de Servicios
.sp 0.6
Repositorio: Hack2-1/proyectodejavi
.ce 0
.bp
.ps 16
.B "1. Proposito del sistema"
.sp 0.4
.ps 11
El sistema automatiza tareas comunes de administracion en equipos GNU/Linux
mediante scripts Bash. El proyecto integra monitoreo de recursos, respaldos,
gestion de usuarios, supervision de servicios, ejecucion remota, monitoreo de
red e inventario del sistema.
.sp 0.3
La solucion se desarrollo con scripts independientes, pero todos comparten
configuracion desde config.txt. Esto permite modificar rutas, umbrales,
servicios, hosts y parametros sin editar el codigo principal.
.sp 0.3
Tambien se integro Telegram para recibir avisos en tiempo real dentro del grupo
PPS, usando un token guardado fuera del repositorio.
.bp
.ps 16
.B "2. Requisitos del proyecto"
.sp 0.4
.ps 11
El documento del proyecto pide siete scripts principales:
.sp 0.2
.IP "\(bu" 3
usuarios.sh
.IP "\(bu" 3
respaldo.sh
.IP "\(bu" 3
monitoreo.sh
.IP "\(bu" 3
servicios.sh
.IP "\(bu" 3
remoto.sh
.IP "\(bu" 3
red.sh
.IP "\(bu" 3
inventario.sh
.sp 0.3
Ademas pide:
.IP "\(bu" 3
config.txt como archivo compartido.
.IP "\(bu" 3
Validacion de parametros y entradas.
.IP "\(bu" 3
Logs con fecha y hora.
.IP "\(bu" 3
Alertas por Telegram.
.IP "\(bu" 3
Uso minimo de root.
.IP "\(bu" 3
trap para interrupciones.
.IP "\(bu" 3
Manual tecnico y presentacion.
.IP "\(bu" 3
Repositorio Git con historial de commits.
.bp
.ps 16
.B "3. Estructura del repositorio"
.sp 0.4
.ps 11
.nf
.
|-- config.txt
|-- configurar-telegram.sh
|-- usuarios.sh
|-- respaldo.sh
|-- monitoreo.sh
|-- servicios.sh
|-- remoto.sh
|-- red.sh
|-- inventario.sh
|-- diagnostico.sh
|-- hosts.txt
|-- crontab.txt
|-- test.sh
|-- setup.sh
|-- README.md
|-- MANUAL_TECNICO.pdf
|-- PRESENTACION_FINAL.pdf
.fi
.sp 0.3
diagnostico.sh no es parte de los siete scripts principales, pero se usa para
probar remoto.sh porque imprime informacion basica de la maquina donde se
ejecuta.
.bp
.ps 16
.B "4. Configuracion central: config.txt"
.sp 0.4
.ps 11
config.txt guarda los parametros reutilizables:
.sp 0.2
.IP "\(bu" 3
CREDENTIALS_FILE: ruta del archivo seguro de Telegram.
.IP "\(bu" 3
LOG_DIR: carpeta donde se guardan logs.
.IP "\(bu" 3
BACKUP_DIR: carpeta de respaldos.
.IP "\(bu" 3
REPORTS_DIR: carpeta de reportes.
.IP "\(bu" 3
INVENTORY_DIR: carpeta de inventarios.
.IP "\(bu" 3
UMBRAL_CPU, UMBRAL_DISCO y UMBRAL_MEMORIA.
.IP "\(bu" 3
SERVICIOS: servicios que revisa servicios.sh.
.IP "\(bu" 3
HOSTS_PING y PUERTOS_CRITICOS.
.IP "\(bu" 3
DIRS_RESPALDO.
.IP "\(bu" 3
USUARIO_REMOTO, PUERTO_SSH y TIMEOUT_SSH.
.sp 0.3
Tambien define dos funciones compartidas:
.sp 0.2
.IP "\(bu" 3
enviar_telegram: manda mensajes al bot.
.IP "\(bu" 3
registrar: escribe eventos en logs.
.bp
.ps 16
.B "5. Rutas usadas por el sistema"
.sp 0.4
.ps 11
Para no depender de root, el proyecto trabaja con rutas del usuario:
.sp 0.2
.nf
Logs:
$HOME/.local/state/sistema-servicios/logs

Reportes:
$HOME/.local/state/sistema-servicios/reportes

Inventarios:
$HOME/.local/state/sistema-servicios/inventarios

Respaldos:
$HOME/respaldos/sistema-servicios

Credenciales Telegram:
$HOME/.config/sistema-servicios/telegram.env
.fi
.sp 0.3
Esto permite ejecutar los scripts desde la terminal de Visual Studio Code sin
usar sudo para todo el proyecto.
.bp
.ps 16
.B "6. Configuracion de Telegram"
.sp 0.4
.ps 11
El bot se configura con:
.sp 0.2
.nf
bash configurar-telegram.sh
.fi
.sp 0.3
El script solicita:
.sp 0.2
.IP "\(bu" 3
Token del bot.
.IP "\(bu" 3
Chat ID del grupo.
.sp 0.3
Para grupos de Telegram, el Chat ID normalmente es negativo. En la prueba se
uso el grupo PPS con un chat id negativo.
.sp 0.3
El archivo generado no se sube a GitHub:
.sp 0.2
.nf
$HOME/.config/sistema-servicios/telegram.env
.fi
.sp 0.3
Prueba de alerta:
.sp 0.2
.nf
bash monitoreo.sh -c 0 -d 0 -m 0
.fi
.bp
.ps 16
.B "7. Uso minimo de root"
.sp 0.4
.ps 11
Una buena practica del proyecto es no ejecutar todo como root. Se aplico de la
siguiente forma:
.sp 0.2
.IP "\(bu" 3
Los logs, reportes, respaldos e inventarios se guardan en HOME.
.IP "\(bu" 3
usuarios.sh no inicia como root obligatoriamente.
.IP "\(bu" 3
usuarios.sh usa sudo solo en useradd, passwd, userdel o usermod.
.IP "\(bu" 3
servicios.sh usa sudo solo si necesita reiniciar servicios.
.IP "\(bu" 3
setup.sh instala sin root en carpetas de usuario.
.sp 0.3
Si setup.sh se ejecuta como root, tambien soporta rutas del sistema como /opt,
/etc y /var, pero no es obligatorio para la demostracion.
.bp
.ps 16
.B "8. usuarios.sh"
.sp 0.4
.ps 11
Funcion:
.br
Permite crear, eliminar, modificar y listar usuarios.
.sp 0.3
Ejecucion:
.sp 0.2
.nf
bash usuarios.sh
.fi
.sp 0.3
Menu:
.sp 0.2
.nf
1. crear usuario
2. eliminar usuario
3. modificar shell de usuario
4. listar usuarios
.fi
.sp 0.3
Validaciones:
.IP "\(bu" 3
No permite usuario vacio.
.IP "\(bu" 3
Valida que el usuario no exista antes de crearlo.
.IP "\(bu" 3
Valida que el usuario exista antes de eliminarlo o modificarlo.
.IP "\(bu" 3
Valida que el shell exista.
.sp 0.3
Salida y evidencia:
.IP "\(bu" 3
Registra en usuarios.log.
.IP "\(bu" 3
Manda Telegram por creacion, eliminacion o modificacion.
.bp
.ps 16
.B "9. respaldo.sh"
.sp 0.4
.ps 11
Funcion:
.br
Comprime directorios usando tar y genera respaldos .tar.gz.
.sp 0.3
Ejecucion con directorios de config.txt:
.sp 0.2
.nf
bash respaldo.sh
.fi
.sp 0.3
Ejecucion indicando directorio:
.sp 0.2
.nf
bash respaldo.sh /home/michael/Documentos
.fi
.sp 0.3
Proceso:
.IP "\(bu" 3
Valida que los directorios existan.
.IP "\(bu" 3
Crea respaldo con tar -czf.
.IP "\(bu" 3
Verifica que el archivo se pueda listar con tar -tzf.
.IP "\(bu" 3
Valida que el archivo tenga tamano mayor a cero.
.IP "\(bu" 3
Elimina respaldos antiguos segun RESPALDO_RETENCION.
.sp 0.3
Telegram:
.br
Manda archivo, tamano y fecha del respaldo.
.bp
.ps 16
.B "10. monitoreo.sh"
.sp 0.4
.ps 11
Funcion:
.br
Lee uso de CPU, disco y memoria.
.sp 0.3
Ejecucion normal:
.sp 0.2
.nf
bash monitoreo.sh
.fi
.sp 0.3
Ejecucion con umbrales personalizados:
.sp 0.2
.nf
bash monitoreo.sh -c 80 -d 85 -m 90
.fi
.sp 0.3
Forzar alerta para evidencia:
.sp 0.2
.nf
bash monitoreo.sh -c 0 -d 0 -m 0
.fi
.sp 0.3
Funcionamiento:
.IP "\(bu" 3
CPU se calcula con top o ps.
.IP "\(bu" 3
Disco se obtiene con df.
.IP "\(bu" 3
Memoria se obtiene con free.
.IP "\(bu" 3
Registra cada lectura aunque no haya alerta.
.IP "\(bu" 3
Manda Telegram si algun valor supera el limite.
.bp
.ps 16
.B "11. servicios.sh"
.sp 0.4
.ps 11
Funcion:
.br
Revisa servicios definidos en config.txt o recibidos como argumentos.
.sp 0.3
Ejecucion:
.sp 0.2
.nf
bash servicios.sh
bash servicios.sh ssh nginx
.fi
.sp 0.3
Proceso:
.IP "\(bu" 3
Valida que systemctl exista.
.IP "\(bu" 3
Revisa con systemctl is-active.
.IP "\(bu" 3
Si esta detenido, intenta reiniciar.
.IP "\(bu" 3
Registra activo, detenido o reiniciado.
.IP "\(bu" 3
Manda Telegram con el resultado.
.sp 0.3
Nota:
.br
En una terminal sin permisos, el reinicio requiere sudo. Revisar estado no
requiere ejecutar todo el script como root.
.bp
.ps 16
.B "12. remoto.sh"
.sp 0.4
.ps 11
Funcion:
.br
Copia un script local a una maquina remota, lo ejecuta por SSH y captura la
salida.
.sp 0.3
Archivo hosts.txt:
.sp 0.2
.nf
192.168.1.72
.fi
.sp 0.3
Ejecucion:
.sp 0.2
.nf
bash remoto.sh diagnostico.sh hosts.txt
.fi
.sp 0.3
Proceso:
.IP "\(bu" 3
Prueba conexion SSH.
.IP "\(bu" 3
Copia el script con scp.
.IP "\(bu" 3
Lo ejecuta en /tmp.
.IP "\(bu" 3
Captura salida y codigo de salida.
.IP "\(bu" 3
Borra el archivo temporal.
.IP "\(bu" 3
Genera reporte general e individual por host.
.bp
.ps 16
.B "13. Prueba remota con VM"
.sp 0.4
.ps 11
La VM usada en la demostracion:
.sp 0.2
.nf
IP: 192.168.1.72
Usuario: michael
Sistema: Debian GNU/Linux 13
.fi
.sp 0.3
Primero se acepto la llave SSH nueva:
.sp 0.2
.nf
ssh -o StrictHostKeyChecking=accept-new michael@192.168.1.72
.fi
.sp 0.3
Luego se ejecuto:
.sp 0.2
.nf
bash remoto.sh diagnostico.sh hosts.txt
.fi
.sp 0.3
El reporte mostro que el script se ejecuto en debian0, con usuario michael,
kernel Debian y recursos de la VM.
.sp 0.5
.B "Scripts que participan en la simulacion:"
.sp 0.2
.IP "\(bu" 3
remoto.sh: es el script principal de la prueba remota.
.IP "\(bu" 3
hosts.txt: contiene la IP o hostname de la VM.
.IP "\(bu" 3
diagnostico.sh: es el script que se copia y ejecuta dentro de la VM.
.IP "\(bu" 3
red.sh: se puede usar aparte para comprobar ping y puertos del host.
.sp 0.4
.B "Flujo exacto de la simulacion:"
.sp 0.2
.IP "1." 3
Se escribe la IP de la VM en hosts.txt.
.IP "2." 3
Se ejecuta bash remoto.sh diagnostico.sh hosts.txt.
.IP "3." 3
remoto.sh se conecta por SSH a michael@192.168.1.72.
.IP "4." 3
Copia diagnostico.sh a /tmp/diagnostico.sh dentro de la VM.
.IP "5." 3
Ejecuta el script dentro de la VM.
.IP "6." 3
Captura la salida del diagnostico.
.IP "7." 3
Borra el archivo temporal de /tmp.
.IP "8." 3
Genera reporte local y manda aviso por Telegram.
.sp 0.4
.B "Comando principal para demostrar servidor remoto:"
.sp 0.2
.nf
bash remoto.sh diagnostico.sh hosts.txt
.fi
.sp 0.4
.B "Comando opcional para revisar conectividad del host:"
.sp 0.2
.nf
bash red.sh -f hosts.txt -p "22 80"
.fi
.sp 0.4
.B "Donde se revisa la evidencia:"
.sp 0.2
.IP "\(bu" 3
En la terminal se ve la salida de diagnostico.sh ejecutada en la VM.
.IP "\(bu" 3
En Telegram llega el mensaje de ejecucion remota.
.IP "\(bu" 3
En REPORTS_DIR quedan el reporte general y el reporte individual.
.IP "\(bu" 3
En la VM no queda el script, porque remoto.sh lo elimina de /tmp al terminar.
.bp
.ps 16
.B "14. red.sh"
.sp 0.4
.ps 11
Funcion:
.br
Verifica conectividad y puertos criticos.
.sp 0.3
Ejecucion con config.txt:
.sp 0.2
.nf
bash red.sh
.fi
.sp 0.3
Ejecucion con archivo y puertos:
.sp 0.2
.nf
bash red.sh -f hosts.txt -p "22 80 443"
.fi
.sp 0.3
Clasificacion:
.IP "\(bu" 3
Accesible: responde ping y tiene todos los puertos abiertos.
.IP "\(bu" 3
Parcial: responde ping pero algun puerto critico esta cerrado.
.IP "\(bu" 3
Sin respuesta: no responde ping.
.sp 0.3
Si hay fallas, manda alerta por Telegram y registra resultados.
.bp
.ps 16
.B "15. inventario.sh"
.sp 0.4
.ps 11
Funcion:
.br
Genera un inventario del sistema en texto plano.
.sp 0.3
Ejecucion:
.sp 0.2
.nf
bash inventario.sh
.fi
.sp 0.3
Datos recopilados:
.IP "\(bu" 3
Sistema operativo, kernel y hostname.
.IP "\(bu" 3
Modelo del procesador y nucleos.
.IP "\(bu" 3
Memoria total, usada y disponible.
.IP "\(bu" 3
Uso de disco por particion.
.IP "\(bu" 3
Interfaces de red.
.IP "\(bu" 3
Usuarios normales.
.IP "\(bu" 3
Servicios activos.
.IP "\(bu" 3
Software instalado.
.sp 0.3
Tambien manda resumen por Telegram con ruta del reporte.
.bp
.ps 16
.B "16. diagnostico.sh"
.sp 0.4
.ps 11
Funcion:
.br
Muestra informacion basica del equipo donde se ejecuta.
.sp 0.3
Ejecucion local:
.sp 0.2
.nf
bash diagnostico.sh
.fi
.sp 0.3
Ejecucion remota:
.sp 0.2
.nf
bash remoto.sh diagnostico.sh hosts.txt
.fi
.sp 0.3
Datos que muestra:
.IP "\(bu" 3
Fecha, host y usuario.
.IP "\(bu" 3
Sistema operativo.
.IP "\(bu" 3
Kernel.
.IP "\(bu" 3
Nucleos CPU.
.IP "\(bu" 3
Memoria.
.IP "\(bu" 3
Disco raiz.
.IP "\(bu" 3
Tiempo encendido.
.bp
.ps 16
.B "17. Cron y automatizacion"
.sp 0.4
.ps 11
El archivo crontab.txt incluye ejemplos para automatizar:
.IP "\(bu" 3
Respaldos diarios.
.IP "\(bu" 3
Monitoreo cada 5 minutos.
.IP "\(bu" 3
Revision de servicios cada 10 minutos.
.IP "\(bu" 3
Monitoreo de red cada 15 minutos.
.IP "\(bu" 3
Inventario diario.
.IP "\(bu" 3
Diagnostico remoto.
.sp 0.3
Para usarlo:
.sp 0.2
.nf
crontab -e
.fi
.sp 0.3
Despues se copian las lineas necesarias desde crontab.txt.
.bp
.ps 16
.B "18. Pruebas del proyecto"
.sp 0.4
.ps 11
Se creo test.sh para validar sin modificar el sistema real.
.sp 0.3
Ejecucion:
.sp 0.2
.nf
bash test.sh
.fi
.sp 0.3
Pruebas realizadas:
.IP "\(bu" 3
Existencia de archivos.
.IP "\(bu" 3
Sintaxis Bash.
.IP "\(bu" 3
setup.sh en modo check.
.IP "\(bu" 3
Ayuda de monitoreo y red.
.IP "\(bu" 3
Ejecucion de diagnostico, inventario y respaldo.
.IP "\(bu" 3
Red con hosts simulados.
.sp 0.3
Resultado final:
.sp 0.2
.nf
total: 29
pasadas: 29
falladas: 0
todas las pruebas pasaron
.fi
.bp
.ps 16
.B "19. Evidencias para la exposicion"
.sp 0.4
.ps 11
Evidencias recomendadas:
.IP "1." 3
Telegram configurado correctamente.
.IP "2." 3
Alerta de monitoreo forzada con -c 0 -d 0 -m 0.
.IP "3." 3
Respaldo generado con ruta, tamano y fecha.
.IP "4." 3
Inventario generado y resumen en Telegram.
.IP "5." 3
Alerta de red con host parcial y host sin respuesta.
.IP "6." 3
Ejecucion remota contra 192.168.1.72.
.IP "7." 3
Reporte remoto legible en REPORTS_DIR.
.IP "8." 3
test.sh con 29 pruebas pasadas.
.bp
.ps 16
.B "20. Errores comunes y solucion"
.sp 0.4
.ps 11
.B "Telegram no llega:"
.br
Revisar que TELEGRAM_ENABLED=true en telegram.env, que el token sea del bot
correcto y que el chat id sea el negativo del grupo.
.sp 0.3
.B "getUpdates sale vacio:"
.br
El bot no recibio mensajes nuevos, el token no es del bot del grupo o hay un
webhook. Usar deleteWebhook y mandar un mensaje nuevo.
.sp 0.3
.B "SSH falla por llave:"
.br
Si la VM cambio, limpiar la llave vieja:
.sp 0.2
.nf
ssh-keygen -R 192.168.1.72
.fi
.sp 0.3
.B "Servicio no reinicia:"
.br
Revisar permisos sudo o ejecutar solo esa accion con privilegios.
.bp
.ps 16
.B "21. Estado final"
.sp 0.4
.ps 11
El sistema quedo alineado con la rubrica:
.IP "\(bu" 3
Siete scripts principales funcionales.
.IP "\(bu" 3
Configuracion centralizada en config.txt.
.IP "\(bu" 3
Validacion de entradas.
.IP "\(bu" 3
Logs con fecha y hora.
.IP "\(bu" 3
Telegram en eventos importantes.
.IP "\(bu" 3
Reportes legibles.
.IP "\(bu" 3
Ejecucion remota real en VM Debian.
.IP "\(bu" 3
Sin tokens reales dentro del repositorio.
.IP "\(bu" 3
GitHub actualizado.
.sp 0.4
Commit principal de scripts:
.br
b7d2438 Actualiza scripts del proyecto integrador
.sp 0.2
Commit de presentacion:
.br
4615129 Actualiza presentacion final del proyecto
