#!/usr/bin/env bash

set -euo pipefail

SDK_DIR="${ANDROID_HOME:-$HOME/Android/Sdk}"
TOOLS_DIR="$SDK_DIR/cmdline-tools"
NDK_VERSION="25.2.9519653"
PLATFORM_VERSION="android-33"
BUILD_TOOLS_VERSION="33.0.2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_ZIP="$SCRIPT_DIR/commandlinetools-linux-11076708_latest.zip"
DOWNLOADS_ZIP="$(find "$HOME/Descargas" "$HOME/Downloads" -maxdepth 1 -type f -name 'commandlinetools-linux-*_latest.zip' 2>/dev/null | head -n 1 || true)"
HOST_UNAME="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST_ARCH="$(uname -m)"
ANDROID_HOST_TAG=""

case "$HOST_UNAME:$HOST_ARCH" in
    linux:x86_64)
        ANDROID_HOST_TAG="linux-x86_64"
        ;;
    linux:i?86)
        ANDROID_HOST_TAG="linux-x86"
        ;;
    darwin:x86_64)
        ANDROID_HOST_TAG="darwin-x86_64"
        ;;
    darwin:arm64)
        ANDROID_HOST_TAG="darwin-arm64"
        ;;
esac

find_java_bin() {
    local java_bin=""

    java_bin="$(command -v java || true)"
    if [ -n "$java_bin" ]; then
        echo "$java_bin"
        return 0
    fi

    java_bin="$(command -v javac || true)"
    if [ -n "$java_bin" ]; then
        java_bin="${java_bin%/javac}/java"
        if [ -x "$java_bin" ]; then
            echo "$java_bin"
            return 0
        fi
    fi

    java_bin="$(update-alternatives --list java 2>/dev/null | head -n 1 || true)"
    if [ -n "$java_bin" ] && [ -x "$java_bin" ]; then
        echo "$java_bin"
        return 0
    fi

    java_bin="$(find /usr/lib/jvm /usr/lib64/jvm -maxdepth 4 -type f -name java 2>/dev/null | head -n 1 || true)"
    if [ -n "$java_bin" ] && [ -x "$java_bin" ]; then
        echo "$java_bin"
        return 0
    fi

    return 1
}

apt_install_java() {
    local apt_cmd="apt-get"
    local sudo_cmd=""
    local official_list=""
    local install_args=(-y --no-install-recommends openjdk-17-jdk unzip)

    if ! command -v apt-get >/dev/null 2>&1; then
        return 1
    fi

    if command -v sudo >/dev/null 2>&1; then
        sudo_cmd="sudo"
    fi

    echo "Intentando instalar OpenJDK 17..."

    if $sudo_cmd $apt_cmd install "${install_args[@]}"; then
        return 0
    fi

    echo "La instalacion directa por apt fallo. Intentando solo con repos oficiales..."

    if [ -f /etc/apt/sources.list.d/official-package-repositories.list ]; then
        official_list="/etc/apt/sources.list.d/official-package-repositories.list"
    elif [ -f /etc/apt/sources.list ]; then
        official_list="/etc/apt/sources.list"
    fi

    if [ -z "$official_list" ]; then
        echo "No encontre un sources.list oficial para aislar repos externos."
        return 1
    fi

    $sudo_cmd $apt_cmd \
        -o Dir::Etc::sourceparts=/dev/null \
        -o Dir::Etc::sourcelist="$official_list" \
        update

    $sudo_cmd $apt_cmd \
        -o Dir::Etc::sourceparts=/dev/null \
        -o Dir::Etc::sourcelist="$official_list" \
        install "${install_args[@]}"
}

configure_lime_android() {
    if ! command -v haxelib >/dev/null 2>&1; then
        echo "No encontre haxelib, asi que no pude escribir la config de Lime."
        echo "Instala/configura Haxe primero y luego corre:"
        echo "  haxelib run lime config ANDROID_SDK \"$ANDROID_HOME\""
        echo "  haxelib run lime config ANDROID_NDK_ROOT \"$ANDROID_NDK_ROOT\""
        echo "  haxelib run lime config JAVA_HOME \"$JAVA_HOME\""
        echo "  haxelib run lime config ANDROID_SETUP true"
        return 1
    fi

    echo "Registrando rutas en la config de Lime..."
    haxelib run lime config ANDROID_SDK "$ANDROID_HOME"
    haxelib run lime config ANDROID_NDK_ROOT "$ANDROID_NDK_ROOT"
    haxelib run lime config JAVA_HOME "$JAVA_HOME"
    if [ -n "$ANDROID_HOST_TAG" ]; then
        haxelib run lime config ANDROID_HOST "$ANDROID_HOST_TAG"
    fi
    haxelib run lime config ANDROID_SETUP true
}

warn_hxcpp_ndk_combo() {
    local current_hxcpp=""

    if ! command -v haxelib >/dev/null 2>&1; then
        return 0
    fi

    current_hxcpp="$(haxelib path hxcpp 2>/dev/null | head -n 1 || true)"

    if [ -n "$current_hxcpp" ] && [[ "$current_hxcpp" == *"/hxcpp/4,3,2/"* ]] && [ "$NDK_VERSION" != "21.4.7075529" ]; then
        echo "Aviso: hxcpp 4.3.2 suele fallar con NDKs mas nuevos que 21.4.7075529."
        echo "Si Android truena en la etapa C++, usa una de estas opciones:"
        echo "  1. Instalar ndk;21.4.7075529 y apuntar ANDROID_NDK_ROOT a esa version"
        echo "  2. Cambiar hxcpp a git: haxelib git hxcpp https://github.com/HaxeFoundation/hxcpp.git"
    fi
}

echo "[1/7] Detectando Java..."

JAVA_BIN="$(find_java_bin || true)"

if [ -z "$JAVA_BIN" ]; then
    echo "Java no esta en PATH."
    if ! apt_install_java; then
        echo "No pude instalar Java automaticamente."
        echo "Parece que tu apt tiene repositorios externos rotos o sin firmas."
        echo "Opciones:"
        echo "  1. Arreglar/desactivar los repos rotos y volver a correr el script"
        echo "  2. Instalar OpenJDK 17 manualmente"
        echo "  3. Exportar JAVA_HOME a un JDK ya instalado y volver a correr el script"
        exit 1
    fi

    JAVA_BIN="$(find_java_bin || true)"
fi

if [ -z "$JAVA_BIN" ]; then
    echo "No pude encontrar java despues de la instalacion."
    exit 1
fi

JAVA_PATH="$(readlink -f "$JAVA_BIN")"
JAVA_HOME="$(dirname "$(dirname "$JAVA_PATH")")"

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

echo "JAVA_HOME=$JAVA_HOME"
java -version

echo "[2/7] Preparando Android SDK..."

mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR"

if [ ! -d "$TOOLS_DIR/latest" ]; then
    ZIP_FILE=""

    if [ -f "$LOCAL_ZIP" ]; then
        ZIP_FILE="$LOCAL_ZIP"
    elif [ -n "$DOWNLOADS_ZIP" ] && [ -f "$DOWNLOADS_ZIP" ]; then
        ZIP_FILE="$DOWNLOADS_ZIP"
    fi

    if [ -z "$ZIP_FILE" ]; then
        echo "No encontre commandlinetools-linux-*_latest.zip."
        echo "Pon el ZIP en:"
        echo "  $SCRIPT_DIR"
        echo "o en Descargas/Downloads y vuelve a correr el script."
        exit 1
    fi

    echo "Usando ZIP: $ZIP_FILE"
    rm -rf latest cmdline-tools tools.zip
    cp -f "$ZIP_FILE" tools.zip
    unzip -o tools.zip
    mv cmdline-tools latest
else
    echo "cmdline-tools/latest ya existe."
fi

echo "[3/7] Configurando variables de entorno..."

export ANDROID_HOME="$SDK_DIR"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/$NDK_VERSION"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"

BASHRC="$HOME/.bashrc"
MARKER="# ANDROID SDK (desktop setup)"

if ! grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
cat >> "$BASHRC" <<EOF

$MARKER
export ANDROID_HOME="\$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="\$ANDROID_HOME"
export ANDROID_NDK_ROOT="\$ANDROID_HOME/ndk/$NDK_VERSION"
export JAVA_HOME="$JAVA_HOME"
export PATH="\$JAVA_HOME/bin:\$PATH"
export PATH="\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin"
export PATH="\$PATH:\$ANDROID_HOME/platform-tools"
EOF
fi

echo "[4/7] Instalando licencias y paquetes Android..."

yes | sdkmanager --licenses

sdkmanager \
    "platform-tools" \
    "platforms;$PLATFORM_VERSION" \
    "build-tools;$BUILD_TOOLS_VERSION" \
    "ndk;$NDK_VERSION"

echo "[5/7] Registrando Android en Lime..."

configure_lime_android

echo "[6/7] Verificando instalacion..."

echo "ANDROID_HOME=$ANDROID_HOME"
echo "ANDROID_NDK_ROOT=$ANDROID_NDK_ROOT"

if [ -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
    echo "OK: cmdline-tools"
else
    echo "Falta cmdline-tools/latest"
    exit 1
fi

if [ -d "$ANDROID_HOME/platform-tools" ]; then
    echo "OK: platform-tools"
else
    echo "Falta platform-tools"
    exit 1
fi

if [ -d "$ANDROID_NDK_ROOT" ]; then
    echo "OK: NDK $NDK_VERSION"
else
    echo "Falta NDK $NDK_VERSION"
    exit 1
fi

warn_hxcpp_ndk_combo

echo "[7/7] Listo."
echo
echo "Siguiente paso recomendado:"
echo "  source \"$BASHRC\""
echo "  haxelib run openfl build android -verbose"
