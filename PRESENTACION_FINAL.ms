.ds FAM H
.nr PO 0.55i
.nr LL 7.4i
.nr HM 0.45i
.nr FM 0.45i
.ps 18
.vs 23
.ce 100
.B "Sistema Automatizado de Servicios con Bash"
.sp 0.4
.ps 14
.B "Proyecto Integrador PPS"
.sp 0.3
Gestor de usuarios, respaldos, monitoreo, servicios, red, ejecucion remota,
inventario y alertas por Telegram.
.sp 0.6
Equipo: PPS
.br
Repositorio: Hack2-1/proyectodejavi
.ce 0
.bp
.ps 18
.B "1. Objetivo del proyecto"
.sp 0.4
.ps 13
El proyecto pide crear un sistema automatizado con scripts Bash para administrar
servicios en GNU/Linux.
.sp 0.3
.IP "\(bu" 3
Leer configuracion desde un archivo comun: config.txt.
.IP "\(bu" 3
Validar entradas y manejar errores.
.IP "\(bu" 3
Registrar acciones en logs.
.IP "\(bu" 3
Enviar alertas y eventos por Telegram.
.IP "\(bu" 3
Evitar ejecutar todo como root cuando no sea necesario.
.IP "\(bu" 3
Probar los scripts y documentar su uso.
.bp
.ps 18
.B "2. Solucion implementada"
.sp 0.4
.ps 13
Se organizaron scripts independientes, pero todos comparten la misma logica:
.sp 0.3
.IP "\(bu" 3
Se carga config.txt.
.IP "\(bu" 3
Se validan parametros, archivos y comandos necesarios.
.IP "\(bu" 3
Se ejecuta la tarea principal.
.IP "\(bu" 3
Se registra el resultado en log.
.IP "\(bu" 3
Se manda Telegram cuando existe evento importante.
.IP "\(bu" 3
Se usa trap para cerrar limpio si se interrumpe el script.
.sp 0.4
Los archivos generados se guardan en rutas del usuario para no depender de root.
.bp
.ps 18
.B "3. Arquitectura del sistema"
.sp 0.4
.ps 13
El sistema se organizo en tres partes:
.sp 0.3
.IP "\(bu" 3
Configuracion: config.txt y telegram.env.
.IP "\(bu" 3
Scripts operativos: usuarios, respaldo, monitoreo, servicios, remoto, red e inventario.
.IP "\(bu" 3
Evidencia: logs, reportes, respaldos, inventarios y mensajes de Telegram.
.sp 0.4
Flujo general:
.sp 0.2
.nf
script -> config.txt -> validacion -> accion -> log/reporte -> Telegram
.fi
.bp
.ps 18
.B "4. Archivos principales"
.sp 0.4
.ps 13
.IP "\(bu" 3
usuarios.sh: administra usuarios.
.IP "\(bu" 3
respaldo.sh: crea respaldos comprimidos.
.IP "\(bu" 3
monitoreo.sh: revisa CPU, disco y memoria.
.IP "\(bu" 3
servicios.sh: revisa y reinicia servicios caidos.
.IP "\(bu" 3
remoto.sh: copia y ejecuta scripts en una VM por SSH.
.IP "\(bu" 3
red.sh: revisa ping, puertos y clasifica hosts.
.IP "\(bu" 3
inventario.sh: genera inventario de hardware y software.
.IP "\(bu" 3
diagnostico.sh: prueba rapida para ejecucion remota.
.IP "\(bu" 3
configurar-telegram.sh: configura token y chat id.
.IP "\(bu" 3
test.sh: ejecuta pruebas seguras.
.bp
.ps 18
.B "5. Configuracion general"
.sp 0.4
.ps 13
El archivo config.txt centraliza los parametros:
.sp 0.3
.IP "\(bu" 3
LOG_DIR: carpeta de logs.
.IP "\(bu" 3
BACKUP_DIR: carpeta de respaldos.
.IP "\(bu" 3
REPORTS_DIR: carpeta de reportes.
.IP "\(bu" 3
INVENTORY_DIR: carpeta de inventarios.
.IP "\(bu" 3
UMBRAL_CPU, UMBRAL_DISCO, UMBRAL_MEMORIA.
.IP "\(bu" 3
SERVICIOS, HOSTS_PING y PUERTOS_CRITICOS.
.IP "\(bu" 3
USUARIO_REMOTO, PUERTO_SSH y TIMEOUT_SSH.
.sp 0.4
Las credenciales reales de Telegram no se guardan en el repositorio.
.bp
.ps 18
.B "6. Rutas usadas sin root"
.sp 0.4
.ps 13
Para cumplir la buena practica de no usar root innecesariamente, el proyecto
trabaja con carpetas del usuario:
.sp 0.3
.nf
Logs:
$HOME/.local/state/sistema-servicios/logs

Reportes:
$HOME/.local/state/sistema-servicios/reportes

Inventarios:
$HOME/.local/state/sistema-servicios/inventarios

Respaldos:
$HOME/respaldos/sistema-servicios
.fi
.sp 0.4
Solo usuarios.sh y servicios.sh usan sudo cuando la accion lo necesita.
.bp
.ps 18
.B "7. Configuracion de Telegram"
.sp 0.4
.ps 13
Se ejecuta:
.sp 0.2
.nf
bash configurar-telegram.sh
.fi
.sp 0.3
El script pide:
.IP "\(bu" 3
Token del bot.
.IP "\(bu" 3
Chat ID del grupo.
.sp 0.3
En la prueba se uso el grupo PPS y el chat id negativo del grupo.
.sp 0.3
Las credenciales quedan guardadas en:
.sp 0.2
.nf
$HOME/.config/sistema-servicios/telegram.env
.fi
.sp 0.3
Para probar alertas:
.sp 0.2
.nf
bash monitoreo.sh -c 0 -d 0 -m 0
.fi
.bp
.ps 18
.B "8. usuarios.sh"
.sp 0.4
.ps 13
Funcion principal: crear, eliminar, modificar y listar usuarios.
.sp 0.3
Ejecucion:
.sp 0.2
.nf
bash usuarios.sh
.fi
.sp 0.3
Muestra un menu:
.IP "\(bu" 3
1. crear usuario
.IP "\(bu" 3
2. eliminar usuario
.IP "\(bu" 3
3. modificar shell
.IP "\(bu" 3
4. listar usuarios
.sp 0.3
Valida si el usuario existe o no existe, registra en usuarios.log y manda
notificacion de Telegram por cada accion realizada.
.bp
.ps 18
.B "9. respaldo.sh"
.sp 0.4
.ps 13
Funcion principal: comprimir directorios con tar y verificar el respaldo.
.sp 0.3
Ejecucion con config.txt:
.nf
bash respaldo.sh
.fi
.sp 0.2
Ejecucion con un directorio especifico:
.nf
bash respaldo.sh /home/michael/Documentos
.fi
.sp 0.3
El script:
.IP "\(bu" 3
Valida que los directorios existan.
.IP "\(bu" 3
Crea un .tar.gz.
.IP "\(bu" 3
Verifica que el archivo exista y tenga tamano mayor a cero.
.IP "\(bu" 3
Registra el resultado y manda ruta, tamano y fecha por Telegram.
.bp
.ps 18
.B "10. monitoreo.sh"
.sp 0.4
.ps 13
Funcion principal: leer CPU, disco y memoria.
.sp 0.3
Ejecucion normal:
.nf
bash monitoreo.sh
.fi
.sp 0.2
Ejecucion con umbrales personalizados:
.nf
bash monitoreo.sh -c 80 -d 85 -m 90
.fi
.sp 0.2
Forzar alerta para la demo:
.nf
bash monitoreo.sh -c 0 -d 0 -m 0
.fi
.sp 0.3
Siempre registra la lectura. Si se supera un limite, manda alerta a Telegram
con saltos de linea legibles.
.bp
.ps 18
.B "11. servicios.sh"
.sp 0.4
.ps 13
Funcion principal: revisar servicios configurados o recibidos por parametro.
.sp 0.3
Ejecucion con config.txt:
.nf
bash servicios.sh
.fi
.sp 0.2
Ejecucion con servicios especificos:
.nf
bash servicios.sh ssh nginx
.fi
.sp 0.3
El script:
.IP "\(bu" 3
Usa systemctl para revisar si esta activo.
.IP "\(bu" 3
Si esta caido, intenta reiniciar.
.IP "\(bu" 3
Usa sudo solo para el reinicio si hace falta.
.IP "\(bu" 3
Registra el estado y manda resultado por Telegram.
.bp
.ps 18
.B "12. remoto.sh y VM"
.sp 0.4
.ps 13
Funcion principal: copiar y ejecutar un script en una maquina remota por SSH.
.sp 0.3
VM usada en prueba:
.nf
IP: 192.168.1.72
Usuario: michael
.fi
.sp 0.3
Ejecucion:
.nf
bash remoto.sh diagnostico.sh hosts.txt
.fi
.sp 0.3
El script copia temporalmente el archivo a:
.nf
/tmp/diagnostico.sh
.fi
.sp 0.3
Luego lo ejecuta, captura la salida, borra el temporal y genera reportes.
.bp
.ps 18
.B "13. Reportes de remoto.sh"
.sp 0.4
.ps 13
remoto.sh genera:
.IP "\(bu" 3
Un reporte general de la ejecucion remota.
.IP "\(bu" 3
Un reporte individual por cada host visitado.
.sp 0.3
Los reportes se guardan en:
.nf
$HOME/.local/state/sistema-servicios/reportes
.fi
.sp 0.3
El reporte incluye:
.IP "\(bu" 3
Fecha.
.IP "\(bu" 3
Script local ejecutado.
.IP "\(bu" 3
Servidor y conexion usada.
.IP "\(bu" 3
Estado de SSH, copia y ejecucion.
.IP "\(bu" 3
Salida capturada del script remoto.
.bp
.ps 18
.B "14. red.sh"
.sp 0.4
.ps 13
Funcion principal: revisar conectividad y puertos.
.sp 0.3
Ejecucion con config.txt:
.nf
bash red.sh
.fi
.sp 0.2
Ejecucion con archivo externo:
.nf
bash red.sh -f hosts.txt -p "22 80 443"
.fi
.sp 0.3
Clasifica cada host como:
.IP "\(bu" 3
accesible
.IP "\(bu" 3
parcialmente accesible
.IP "\(bu" 3
sin respuesta
.sp 0.3
Si hay fallas, manda alerta por Telegram.
.bp
.ps 18
.B "15. inventario.sh"
.sp 0.4
.ps 13
Funcion principal: generar inventario de hardware y software.
.sp 0.3
Ejecucion:
.nf
bash inventario.sh
.fi
.sp 0.3
Incluye:
.IP "\(bu" 3
Sistema operativo, kernel y hostname.
.IP "\(bu" 3
Modelo de CPU y nucleos.
.IP "\(bu" 3
RAM total, usada y disponible.
.IP "\(bu" 3
Uso de disco por particion.
.IP "\(bu" 3
Interfaces, usuarios, servicios y software instalado.
.sp 0.3
Tambien manda resumen por Telegram y guarda reporte en INVENTORY_DIR.
.bp
.ps 18
.B "16. Cron y automatizacion"
.sp 0.4
.ps 13
El proyecto incluye crontab.txt con ejemplos para programar tareas:
.sp 0.3
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
Se usa con:
.sp 0.2
.nf
crontab -e
.fi
.bp
.ps 18
.B "17. Comandos clave para la demo"
.sp 0.4
.ps 13
.nf
bash configurar-telegram.sh
bash monitoreo.sh -c 0 -d 0 -m 0
bash respaldo.sh /tmp/carpeta_prueba
bash inventario.sh
bash red.sh -f hosts.txt -p "22 80"
bash remoto.sh diagnostico.sh hosts.txt
bash test.sh
.fi
.sp 0.4
Estos comandos muestran alertas, reportes, respaldos, inventario y ejecucion
remota.
.bp
.ps 18
.B "18. Evidencias que se deben mostrar"
.sp 0.4
.ps 13
.IP "1." 3
Telegram configurado en el grupo PPS.
.IP "2." 3
Alerta de monitoreo con CPU, disco y memoria.
.IP "3." 3
Respaldo generado con ruta, tamano y fecha.
.IP "4." 3
Inventario generado y resumen enviado.
.IP "5." 3
Alerta de red con host parcial o sin respuesta.
.IP "6." 3
Ejecucion remota en VM Debian 192.168.1.72.
.IP "7." 3
Reporte remoto legible en REPORTS_DIR.
.IP "8." 3
test.sh con todas las pruebas pasadas.
.bp
.ps 18
.B "19. Problemas resueltos"
.sp 0.4
.ps 13
Durante la integracion se resolvieron detalles reales del proyecto:
.sp 0.3
.IP "\(bu" 3
Telegram estaba usando un bot incorrecto; se configuro el bot PPS.
.IP "\(bu" 3
El Chat ID del grupo era negativo; se obtuvo desde getUpdates.
.IP "\(bu" 3
Los saltos de linea salian como texto \\n; se corrigio el formato.
.IP "\(bu" 3
SSH tenia una llave vieja de la VM; se actualizo known_hosts.
.IP "\(bu" 3
Los reportes remotos eran dificiles de leer; se mejoro el formato.
.IP "\(bu" 3
Se evitaron rutas /var y /etc por defecto para no depender de root.
.bp
.ps 18
.B "20. Pruebas y evidencia"
.sp 0.4
.ps 13
Se creo test.sh para validar de forma segura:
.sp 0.2
.nf
bash test.sh
.fi
.sp 0.3
Resultado final:
.nf
total: 29
pasadas: 29
falladas: 0
todas las pruebas pasaron
.fi
.sp 0.3
Tambien se verifico:
.IP "\(bu" 3
Telegram en el grupo PPS.
.IP "\(bu" 3
Ejecucion remota real contra Debian VM.
.IP "\(bu" 3
Generacion de reportes, respaldos e inventarios.
.IP "\(bu" 3
GitHub actualizado con el commit final.
.bp
.ps 18
.B "21. Cierre"
.sp 0.4
.ps 13
El sistema cumple los puntos principales del proyecto:
.sp 0.3
.IP "\(bu" 3
Scripts funcionales e independientes.
.IP "\(bu" 3
Configuracion centralizada.
.IP "\(bu" 3
Logs y reportes.
.IP "\(bu" 3
Notificaciones en tiempo real por Telegram.
.IP "\(bu" 3
Ejecucion remota por SSH.
.IP "\(bu" 3
Buenas practicas: validaciones, trap y uso minimo de root.
.sp 0.5
.B "Demostracion sugerida:"
.sp 0.2
1. monitoreo con alerta.
.br
2. respaldo.
.br
3. inventario.
.br
4. remoto contra la VM.
.br
5. revision de reportes generados.
