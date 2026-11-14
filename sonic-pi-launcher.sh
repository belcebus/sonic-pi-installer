#!/usr/bin/bash
set -o pipefail

APP_DIR="$HOME/.local/share/sonic-pi-app"
EXEC_PATH="$APP_DIR/sonic-pi"
VERSION_FILE="$APP_DIR/VERSION"
ICON_PATH="$APP_DIR/sonic-pi.png"
ICON_URL="https://raw.githubusercontent.com/sonic-pi-net/sonic-pi/dev/app/gui/images/icon.png"
DESKTOP_FILE="$HOME/.local/share/applications/sonic-pi.desktop"
TMP_APPIMAGE=""
TMP_VERSION=""
TMP_ICON=""

cleanup() {
  [ -z "$TMP_APPIMAGE" ] || rm -f -- "$TMP_APPIMAGE"
  [ -z "$TMP_VERSION" ] || rm -f -- "$TMP_VERSION"
  [ -z "$TMP_ICON" ] || rm -f -- "$TMP_ICON"
}
trap cleanup EXIT

if [ "$1" = "--uninstall" ]; then
  echo "ℹ️  Desinstalando Sonic Pi..."
  if ! rm -rf -- "$APP_DIR" || ! rm -f -- "$DESKTOP_FILE"; then
    echo "❌  No se pudo completar la desinstalación." >&2
    exit 1
  fi
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications/" || {
      echo "❌  No se pudo actualizar la base de datos de aplicaciones." >&2
      exit 1
    }
  else
    echo "⚠️  No se encontró update-desktop-database; se omitió actualizar la base de datos."
  fi
  echo "✅  Desinstalación completada."
  exit 0
fi

PLATFORM="$(uname -m)"
if [ "$PLATFORM" = "x86_64" ]; then
  PLATFORM="Linux-x64"
elif [ "$PLATFORM" = "i686" ] || [ "$PLATFORM" = "i386" ]; then
  PLATFORM="Linux-x86"
elif [ "$PLATFORM" = "aarch64" ]; then
  PLATFORM="Linux-arm64"
else
  echo "❌  Plataforma no soportada: $PLATFORM"
  exit 1
fi

if ! mkdir -p "$APP_DIR"; then
  echo "❌  No se pudo crear el directorio de la aplicación: $APP_DIR" >&2
  exit 1
fi

if [ "$0" != "$APP_DIR/sonic-pi-launcher.sh" ] &&
  ! cp "$0" "$APP_DIR/sonic-pi-launcher.sh"; then
  echo "❌  No se pudo copiar el launcher al directorio de la aplicación." >&2
  exit 1
fi

CURRENT_VERSION=""
if [ -f "$VERSION_FILE" ]; then
  IFS= read -r CURRENT_VERSION < "$VERSION_FILE" || CURRENT_VERSION=""
fi

LATEST_VERSION=""
if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  if ! LATEST_VERSION=$(
    curl --fail --silent --show-error --location \
      --connect-timeout 10 --max-time 30 \
      "https://api.github.com/repos/sonic-pi-net/sonic-pi/releases/latest" |
      jq --exit-status --raw-output \
        '.tag_name | select(type == "string" and test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))'
  ); then
    LATEST_VERSION=""
    echo "⚠️  No se pudo consultar una versión estable en GitHub." >&2
  fi
else
  echo "⚠️  Se necesitan curl y jq para consultar actualizaciones." >&2
fi

if [ -n "$LATEST_VERSION" ]; then
  if [ ! -x "$EXEC_PATH" ] || [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
    echo "ℹ️  Descargando Sonic Pi $LATEST_VERSION..."
    TMP_APPIMAGE=$(mktemp "$APP_DIR/.sonic-pi.XXXXXX") || {
      echo "❌  No se pudo crear un archivo temporal para la descarga." >&2
      exit 1
    }
    if ! curl --fail --silent --show-error --location \
      --connect-timeout 10 --max-time 600 \
      --output "$TMP_APPIMAGE" \
      "https://sonic-pi.net/files/releases/$LATEST_VERSION/Sonic-Pi-for-$PLATFORM-$LATEST_VERSION.AppImage"; then
      echo "❌  No se pudo descargar Sonic Pi $LATEST_VERSION." >&2
      if [ ! -x "$EXEC_PATH" ]; then
        exit 1
      fi
      echo "⚠️  Se conservará la instalación existente."
    elif [ ! -s "$TMP_APPIMAGE" ]; then
      echo "❌  La descarga de Sonic Pi está vacía." >&2
      if [ ! -x "$EXEC_PATH" ]; then
        exit 1
      fi
      echo "⚠️  Se conservará la instalación existente."
    else
      APPIMAGE_MAGIC=""
      IFS= read -r -N 4 APPIMAGE_MAGIC < "$TMP_APPIMAGE" || true
      if [ "$APPIMAGE_MAGIC" != $'\177ELF' ]; then
        echo "❌  El archivo descargado no parece ser una AppImage válida." >&2
        if [ ! -x "$EXEC_PATH" ]; then
          exit 1
        fi
        echo "⚠️  Se conservará la instalación existente."
      elif ! chmod +x "$TMP_APPIMAGE"; then
        echo "❌  No se pudieron establecer permisos de ejecución para la AppImage." >&2
        if [ ! -x "$EXEC_PATH" ]; then
          exit 1
        fi
        echo "⚠️  Se conservará la instalación existente."
      else
        TMP_VERSION=$(mktemp "$APP_DIR/.VERSION.XXXXXX") || {
          echo "❌  No se pudo crear un archivo temporal para la versión." >&2
          exit 1
        }
        if ! printf '%s\n' "$LATEST_VERSION" > "$TMP_VERSION"; then
          echo "❌  No se pudo guardar la versión descargada." >&2
          exit 1
        elif ! mv -f -- "$TMP_APPIMAGE" "$EXEC_PATH"; then
          echo "❌  No se pudo instalar la AppImage descargada." >&2
          exit 1
        else
          TMP_APPIMAGE=""
          if ! mv -f -- "$TMP_VERSION" "$VERSION_FILE"; then
            echo "❌  La AppImage se instaló, pero no se pudo actualizar el archivo VERSION." >&2
            exit 1
          fi
          TMP_VERSION=""
          echo "✅  Sonic Pi $LATEST_VERSION quedó instalado."
        fi
      fi
    fi
  else
    echo "ℹ️  La versión actual ($CURRENT_VERSION) está actualizada."
  fi
elif [ ! -x "$EXEC_PATH" ]; then
  echo "❌  No hay una AppImage ejecutable y no se pudo consultar una versión para descargar." >&2
  exit 1
else
  echo "⚠️  Se iniciará la instalación existente sin comprobar actualizaciones." >&2
fi

if [ ! -f "$ICON_PATH" ] && command -v curl >/dev/null 2>&1; then
  echo "ℹ️  Descargando el icono..."
  TMP_ICON=$(mktemp "$APP_DIR/.sonic-pi-icon.XXXXXX") || {
    echo "⚠️  No se pudo crear un archivo temporal para el icono." >&2
  }
  if [ -n "$TMP_ICON" ]; then
    if curl --fail --silent --show-error --location \
      --connect-timeout 10 --max-time 60 --output "$TMP_ICON" "$ICON_URL" &&
      [ -s "$TMP_ICON" ] && mv -f -- "$TMP_ICON" "$ICON_PATH"; then
      TMP_ICON=""
    else
      echo "⚠️  No se pudo descargar el icono; el launcher continuará sin él." >&2
    fi
  fi
fi

echo "ℹ️  Creando el acceso directo .desktop..."
if ! mkdir -p "$(dirname "$DESKTOP_FILE")"; then
  echo "❌  No se pudo crear el directorio de aplicaciones." >&2
  exit 1
fi
cat > "$DESKTOP_FILE" <<EOL
[Desktop Entry]
Name=Sonic Pi
Comment=Live Coding Music Synth
Exec=$APP_DIR/sonic-pi-launcher.sh
Icon=$ICON_PATH
Type=Application
Categories=AudioVideo;Audio;Music;Development;
StartupWMClass=Sonic-pi
Terminal=false
EOL
if ! chmod +x "$DESKTOP_FILE"; then
  echo "❌  No se pudieron establecer permisos para el acceso directo." >&2
  exit 1
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  if ! update-desktop-database "$HOME/.local/share/applications/"; then
    echo "⚠️  No se pudo actualizar la base de datos de aplicaciones." >&2
  fi
else
  echo "⚠️  No se encontró update-desktop-database; el acceso directo se creó de todos modos."
fi
echo "ℹ️  Acceso directo .desktop actualizado."


# Ejecutar la aplicación Sonic Pi
exec "$EXEC_PATH" "$@"
