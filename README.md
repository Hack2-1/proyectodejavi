# Sistema Automatizado de Servicios con Bash

Proyecto integrador de Bash para administrar y supervisar equipos GNU/Linux.
El sistema usa scripts independientes, un archivo compartido `config.txt`,
logs, reportes y alertas por Telegram.

## Scripts

| Script | Funcion |
| --- | --- |
| `usuarios.sh` | Crear, eliminar, modificar y listar usuarios. |
| `respaldo.sh` | Crear respaldos comprimidos con `tar` y verificar que se generaron. |
| `monitoreo.sh` | Revisar CPU, disco y memoria con umbrales configurables. |
| `servicios.sh` | Revisar servicios y tratar de reiniciar los que esten caidos. |
| `remoto.sh` | Copiar y ejecutar scripts en una maquina remota por SSH. |
| `red.sh` | Revisar ping, puertos y clasificar hosts. |
| `inventario.sh` | Generar inventario de hardware y software. |
| `diagnostico.sh` | Mostrar diagnostico basico, usado para pruebas remotas. |
| `configurar-telegram.sh` | Guardar token y chat id del bot fuera del repositorio. |
| `test.sh` | Ejecutar pruebas seguras del proyecto. |

## Configuracion

Los parametros principales estan en:

```bash
config.txt
```

Ahí se configuran:

- rutas de logs, reportes, respaldos e inventarios
- umbrales de monitoreo
- servicios a revisar
- hosts y puertos de red
- usuario remoto SSH
- archivo de credenciales de Telegram

Por defecto el proyecto trabaja sin root y guarda archivos en carpetas del usuario:

```bash
$HOME/.local/state/sistema-servicios/logs
$HOME/.local/state/sistema-servicios/reportes
$HOME/.local/state/sistema-servicios/inventarios
$HOME/respaldos/sistema-servicios
```

## Telegram

Configura el bot con:

```bash
bash configurar-telegram.sh
```

El script pide:

```text
Token del bot
Chat ID
```

Para grupo de Telegram, el `Chat ID` normalmente es negativo, por ejemplo:

```text
-5525562000
```

Las credenciales se guardan fuera del repositorio:

```bash
$HOME/.config/sistema-servicios/telegram.env
```

Prueba rapida de alerta:

```bash
bash monitoreo.sh -c 0 -d 0 -m 0
```

## Uso De Scripts

### usuarios.sh

Muestra un menu:

```bash
bash usuarios.sh
```

Opciones:

```text
1. crear usuario
2. eliminar usuario
3. modificar shell de usuario
4. listar usuarios
```

El script no necesita abrirse como root. Si la accion requiere permisos, usa
`sudo` solamente en el comando necesario.

### respaldo.sh

Usa los directorios de `config.txt`:

```bash
bash respaldo.sh
```

O recibe directorios:

```bash
bash respaldo.sh /home/michael/Documentos
```

Genera respaldos en:

```bash
$HOME/respaldos/sistema-servicios
```

### monitoreo.sh

Usa umbrales de `config.txt`:

```bash
bash monitoreo.sh
```

Con umbrales personalizados:

```bash
bash monitoreo.sh -c 80 -d 85 -m 90
```

Para forzar alerta en la demostracion:

```bash
bash monitoreo.sh -c 0 -d 0 -m 0
```

### servicios.sh

Usa servicios de `config.txt`:

```bash
bash servicios.sh
```

O recibe servicios:

```bash
bash servicios.sh ssh nginx
```

Si un servicio esta caido, intenta reiniciarlo con root o `sudo`.

### red.sh

Usa hosts y puertos de `config.txt`:

```bash
bash red.sh
```

Con archivo externo y puertos:

```bash
bash red.sh -f hosts.txt -p "22 80 443"
```

Clasifica hosts como accesibles, parciales o sin respuesta.

### inventario.sh

Genera inventario:

```bash
bash inventario.sh
```

El reporte queda en:

```bash
$HOME/.local/state/sistema-servicios/inventarios
```

Tambien envia resumen por Telegram si esta configurado.

### remoto.sh

Ejecuta un script en hosts remotos.

Archivo `hosts.txt`:

```text
192.168.1.72
```

Ejecucion:

```bash
bash remoto.sh diagnostico.sh hosts.txt
```

El script copia temporalmente el archivo a la VM:

```bash
/tmp/diagnostico.sh
```

Lo ejecuta, captura la salida y luego lo elimina.

Los reportes quedan en:

```bash
$HOME/.local/state/sistema-servicios/reportes
```

### diagnostico.sh

Se puede ejecutar local:

```bash
bash diagnostico.sh
```

Tambien sirve como script de prueba para `remoto.sh`.

## Cron

El archivo `crontab.txt` trae ejemplos para programar:

- respaldos diarios
- monitoreo cada 5 minutos
- revision de servicios
- monitoreo de red
- inventarios periodicos
- diagnostico remoto

Para usarlo:

```bash
crontab -e
```

y copia las lineas que necesites.

## Pruebas

Ejecuta:

```bash
chmod +x ./*.sh
bash test.sh
```

Las pruebas son seguras:

- no crean usuarios reales
- no reinician servicios reales
- no hacen SSH real
- usan carpetas temporales

## Prueba Real Con La VM

La VM usada en pruebas tiene:

```text
IP: 192.168.1.72
Usuario: michael
```

Primero se valida SSH:

```bash
ssh -o StrictHostKeyChecking=accept-new michael@192.168.1.72
```

Despues se ejecuta:

```bash
bash remoto.sh diagnostico.sh hosts.txt
```

## Archivos Generados

Logs:

```bash
$HOME/.local/state/sistema-servicios/logs
```

Reportes remotos:

```bash
$HOME/.local/state/sistema-servicios/reportes
```

Inventarios:

```bash
$HOME/.local/state/sistema-servicios/inventarios
```

Respaldos:

```bash
$HOME/respaldos/sistema-servicios
```

## Seguridad

- No se guardan tokens reales dentro de `config.txt`.
- Telegram usa `$HOME/.config/sistema-servicios/telegram.env`.
- Los scripts no se ejecutan como root completos.
- Solo usan `sudo` cuando una accion realmente lo necesita.
- SSH usa llaves y acepta llaves nuevas con `StrictHostKeyChecking=accept-new`.
