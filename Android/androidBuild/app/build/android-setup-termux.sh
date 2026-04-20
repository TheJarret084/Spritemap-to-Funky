#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "📦 Actualizando paquetes..."
pkg update -y && pkg upgrade -y

echo "🧰 Instalando dependencias..."
pkg install -y openjdk-17 wget unzip git clang cmake make

# =========================
# DETECTAR JAVA_HOME (CLAVE)
# =========================
echo "☕ Detectando Java..."

JAVA_BIN=$(command -v java || true)

if [ -z "$JAVA_BIN" ]; then
    echo "❌ Java no encontrado en PATH"
    exit 1
fi

JAVA_PATH=$(readlink -f "$JAVA_BIN")
JAVA_HOME=$(dirname $(dirname "$JAVA_PATH"))

export JAVA_HOME
export PATH=$JAVA_HOME/bin:$PATH

if [ -z "$JAVA_PATH" ]; then
    echo "❌ Java no encontrado"
    exit 1
fi

JAVA_HOME=$(dirname $(dirname "$JAVA_PATH"))
export JAVA_HOME
export PATH=$JAVA_HOME/bin:$PATH

echo "✔️ JAVA_HOME detectado en:"
echo "$JAVA_HOME"

java -version || { echo "❌ Java no funciona"; exit 1; }

# =========================
# ANDROID SDK
# =========================
SDK_DIR="$HOME/Android/Sdk"
TOOLS_DIR="$SDK_DIR/cmdline-tools"
ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

echo "📥 Preparando SDK..."
mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR"

if [ ! -d "latest" ]; then
    echo "⬇️ Descargando command-line tools..."
    wget -O tools.zip "$ZIP_URL"
    unzip -o tools.zip
    mv cmdline-tools latest
else
    echo "✔️ Command-line tools ya existen"
fi

# =========================
# VARIABLES DE ENTORNO
# =========================
echo "⚙️ Configurando entorno..."

BASHRC="$HOME/.bashrc"

if ! grep -q "ANDROID_HOME" "$BASHRC"; then
cat >> "$BASHRC" <<EOF

# ANDROID SDK (Termux)
export ANDROID_HOME=\$HOME/Android/Sdk
export ANDROID_SDK_ROOT=\$ANDROID_HOME
export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=\$PATH:\$ANDROID_HOME/platform-tools
export ANDROID_NDK_ROOT=\$ANDROID_HOME/ndk/25.2.9519653

# JAVA (auto detectado)
export JAVA_HOME=$JAVA_HOME
JAVA_BIN=$(command -v java || true)

if [ -z "$JAVA_BIN" ]; then
    echo "❌ Java no encontrado en PATH"
    exit 1
fi

JAVA_PATH=$(readlink -f "$JAVA_BIN")
JAVA_HOME=$(dirname $(dirname "$JAVA_PATH"))

export JAVA_HOME
export PATH=$JAVA_HOME/bin:$PATH

EOF
fi

# aplicar variables en esta sesión
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/25.2.9519653

# =========================
# INSTALAR SDK
# =========================
echo "📲 Instalando SDK..."

yes | sdkmanager --licenses

sdkmanager \
"platform-tools" \
"platforms;android-33" \
"build-tools;33.0.2" \
"ndk;25.2.9519653"

# =========================
# VERIFICACIÓN FINAL
# =========================
echo "🧪 Verificando instalación..."

if [ -d "$ANDROID_HOME/ndk" ]; then
    echo "✔️ NDK instalado:"
    ls "$ANDROID_HOME/ndk"
else
    echo "⚠️ NDK no encontrado"
fi

echo "✅ TODO LISTO (si nada explotó 😆)"
echo ""
echo "👉 Ahora ejecuta:"
echo "lime setup android"
echo "lime build android -verbose"