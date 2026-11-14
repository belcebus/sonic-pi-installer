# Sonic Pi Launcher para Linux

Este repositorio contiene un launcher Bash que descarga y ejecuta la versión
estable más reciente de Sonic Pi para Linux. También crea un acceso directo en
el menú de aplicaciones y permite desinstalar los archivos que administra.

## Requisitos

- Linux de 64 bits (`x86_64` o `aarch64`) o de 32 bits (`i386`/`i686`).
- Bash.
- `curl` y `jq` para consultar las versiones y descargar Sonic Pi.
- Una conexión a Internet para la instalación inicial y las actualizaciones.

Si `curl` o `jq` no están disponibles, el launcher puede ejecutar una
instalación existente, pero no podrá comprobar ni descargar actualizaciones.
Necesita una AppImage ejecutable para iniciar Sonic Pi.

## Instalación y ejecución

Desde una copia local de este repositorio:

```bash
chmod +x sonic-pi-launcher.sh
./sonic-pi-launcher.sh
```

La primera ejecución consulta la última versión estable publicada en GitHub,
descarga la AppImage correspondiente a la arquitectura detectada y la inicia.
En ejecuciones posteriores vuelve a comprobar si hay una versión nueva.

El launcher administra estos archivos dentro de tu directorio personal:

- Aplicación y versión: `~/.local/share/sonic-pi-app/`
- Acceso directo: `~/.local/share/applications/sonic-pi.desktop`

El acceso directo también permite iniciar Sonic Pi desde el menú de
aplicaciones. Si está instalado `update-desktop-database`, el launcher
actualiza la base de datos de aplicaciones.

## Desinstalación

Ejecuta el launcher con la opción `--uninstall`:

```bash
./sonic-pi-launcher.sh --uninstall
```

Esto elimina `~/.local/share/sonic-pi-app/` y el acceso directo
`~/.local/share/applications/sonic-pi.desktop`.

## Actualizaciones y funcionamiento sin conexión

Al iniciar, el launcher consulta la API de releases de Sonic Pi y solo acepta
etiquetas de versión con el formato `vM.m.p`. Descarga la AppImage a un archivo
temporal, comprueba que no esté vacía y que comience con la firma ELF, y luego
la instala. Si la consulta o descarga falla, conserva una instalación
ejecutable existente. Sin una instalación existente ni acceso a una versión
descargable, termina con un error.
