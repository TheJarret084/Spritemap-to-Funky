#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/app"
DIST_DIR="$ROOT_DIR/dist"
ANDROID_APP_DIR="$APP_DIR/bin/android/bin/app"
APK_OUTPUT_DIR="$ANDROID_APP_DIR/build/outputs/apk"
BUNDLE_OUTPUT_DIR="$ANDROID_APP_DIR/build/outputs/bundle"
GRADLE_PROJECT_DIR="$APP_DIR/bin/android/bin"
SIGNING_PROPERTIES_PATH="$ANDROID_APP_DIR/signing.properties"
ROOT_SIGNING_PROPERTIES_PATH="$ROOT_DIR/signing.properties"
APP_SIGNING_PROPERTIES_PATH="$APP_DIR/signing.properties"
LAST_BUILT_APK=""
LAST_BUILT_APKS=()
LAST_BUILT_AAB=""
LAST_BUILT_AABS=()

ensure_release_signing() {
    if [ -f "$SIGNING_PROPERTIES_PATH" ]; then
        return
    fi

    if [ -f "$APP_SIGNING_PROPERTIES_PATH" ]; then
        cp -f "$APP_SIGNING_PROPERTIES_PATH" "$SIGNING_PROPERTIES_PATH"
        echo "Se copio signing.properties desde $APP_SIGNING_PROPERTIES_PATH"
        return
    fi

    if [ -f "$ROOT_SIGNING_PROPERTIES_PATH" ]; then
        cp -f "$ROOT_SIGNING_PROPERTIES_PATH" "$SIGNING_PROPERTIES_PATH"
        echo "Se copio signing.properties desde $ROOT_SIGNING_PROPERTIES_PATH"
        return
    fi

    if [ -n "${KEY_STORE:-}" ] && [ -n "${KEY_STORE_PASSWORD:-}" ] && [ -n "${KEY_STORE_ALIAS:-}" ] && [ -n "${KEY_STORE_ALIAS_PASSWORD:-}" ]; then
        local keystore_path="$KEY_STORE"
        if [ ! -f "$keystore_path" ] && [ -f "$ROOT_DIR/$keystore_path" ]; then
            keystore_path="$ROOT_DIR/$keystore_path"
        fi

        if [ ! -f "$keystore_path" ]; then
            echo "No encontre el keystore configurado en KEY_STORE: $KEY_STORE"
            exit 1
        fi

        cat > "$SIGNING_PROPERTIES_PATH" <<EOF
KEY_STORE=$keystore_path
KEY_STORE_PASSWORD=$KEY_STORE_PASSWORD
KEY_STORE_ALIAS=$KEY_STORE_ALIAS
KEY_STORE_ALIAS_PASSWORD=$KEY_STORE_ALIAS_PASSWORD
EOF
        echo "Se genero signing.properties para Gradle en $SIGNING_PROPERTIES_PATH"
        return
    fi

    cat <<EOF
Falta configuracion de firma para compilar el AAB release.

Gradle buscara $SIGNING_PROPERTIES_PATH y ahorita no existe.

Opciones:
1. Crear ese archivo con:
   KEY_STORE=/ruta/a/tu.keystore
   KEY_STORE_PASSWORD=...
   KEY_STORE_ALIAS=...
   KEY_STORE_ALIAS_PASSWORD=...
2. O exportar esas mismas variables de entorno antes de correr este script.

El AAB release necesita firma; sin eso bundleRelease termina fallando al final.
EOF
    exit 1
}

require_release_signing_config() {
    if [ -f "$SIGNING_PROPERTIES_PATH" ] || [ -f "$APP_SIGNING_PROPERTIES_PATH" ] || [ -f "$ROOT_SIGNING_PROPERTIES_PATH" ]; then
        return
    fi

    if [ -n "${KEY_STORE:-}" ] && [ -n "${KEY_STORE_PASSWORD:-}" ] && [ -n "${KEY_STORE_ALIAS:-}" ] && [ -n "${KEY_STORE_ALIAS_PASSWORD:-}" ]; then
        return
    fi

    cat <<EOF
Falta configuracion de firma para compilar el AAB release.

Busca uno de estos archivos:
 - $ROOT_SIGNING_PROPERTIES_PATH
 - $APP_SIGNING_PROPERTIES_PATH

O estas variables de entorno:
 - KEY_STORE
 - KEY_STORE_PASSWORD
 - KEY_STORE_ALIAS
 - KEY_STORE_ALIAS_PASSWORD
EOF
    exit 1
}

build_variant() {
    local label="$1"
    local build_flag="$2"
    shift 2
    local extra_args=("$@")
    local before_list
    local after_list

    echo "==> Building $label"

    before_list="$(find "$APK_OUTPUT_DIR" -type f -name '*.apk' 2>/dev/null | sort || true)"
    (
        cd "$APP_DIR"
        # Evita que Gradle/Lime recicle drawables o assets viejos entre builds.
        haxelib run lime clean project.xml android
        haxelib run lime build project.xml android "$build_flag" "${extra_args[@]}"
    )
    after_list="$(find "$APK_OUTPUT_DIR" -type f -name '*.apk' 2>/dev/null | sort || true)"

    mapfile -t LAST_BUILT_APKS < <(comm -13 <(printf '%s\n' "$before_list") <(printf '%s\n' "$after_list") | sed '/^$/d')

    LAST_BUILT_APK=""
    if [ ${#LAST_BUILT_APKS[@]} -gt 0 ]; then
        LAST_BUILT_APK="${LAST_BUILT_APKS[${#LAST_BUILT_APKS[@]}-1]}"
    fi
    if [ -z "$LAST_BUILT_APK" ]; then
        LAST_BUILT_APK="$(find "$APK_OUTPUT_DIR" -type f -name '*.apk' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)"
        if [ -n "$LAST_BUILT_APK" ]; then
            LAST_BUILT_APKS=("$LAST_BUILT_APK")
        fi
    fi

    if [ ${#LAST_BUILT_APKS[@]} -eq 0 ] || [ -z "$LAST_BUILT_APK" ] || [ ! -f "$LAST_BUILT_APK" ]; then
        echo "No pude localizar la APK generada dentro de $APK_OUTPUT_DIR"
        exit 1
    fi

    echo "APKs detectadas:"
    for apk in "${LAST_BUILT_APKS[@]}"; do
        echo " - $apk"
    done
}

build_bundle_variant() {
    local label="$1"
    local build_flag="$2"
    local gradle_task="$3"
    shift 3
    local extra_args=("$@")
    local before_list
    local after_list

    echo "==> Building $label"
    require_release_signing_config

    before_list="$(find "$BUNDLE_OUTPUT_DIR" -type f -name '*.aab' 2>/dev/null | sort || true)"
    (
        cd "$APP_DIR"
        haxelib run lime clean project.xml android
        haxelib run lime build project.xml android "$build_flag" "${extra_args[@]}"
    )
    ensure_release_signing
    (
        cd "$GRADLE_PROJECT_DIR"
        ./gradlew "$gradle_task"
    )
    after_list="$(find "$BUNDLE_OUTPUT_DIR" -type f -name '*.aab' 2>/dev/null | sort || true)"

    mapfile -t LAST_BUILT_AABS < <(comm -13 <(printf '%s\n' "$before_list") <(printf '%s\n' "$after_list") | sed '/^$/d')

    LAST_BUILT_AAB=""
    if [ ${#LAST_BUILT_AABS[@]} -gt 0 ]; then
        LAST_BUILT_AAB="${LAST_BUILT_AABS[${#LAST_BUILT_AABS[@]}-1]}"
    fi
    if [ -z "$LAST_BUILT_AAB" ]; then
        LAST_BUILT_AAB="$(find "$BUNDLE_OUTPUT_DIR" -type f -name '*.aab' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)"
        if [ -n "$LAST_BUILT_AAB" ]; then
            LAST_BUILT_AABS=("$LAST_BUILT_AAB")
        fi
    fi

    if [ ${#LAST_BUILT_AABS[@]} -eq 0 ] || [ -z "$LAST_BUILT_AAB" ] || [ ! -f "$LAST_BUILT_AAB" ]; then
        echo "No pude localizar el AAB generado dentro de $BUNDLE_OUTPUT_DIR"
        exit 1
    fi

    echo "AABs detectados:"
    for aab in "${LAST_BUILT_AABS[@]}"; do
        echo " - $aab"
    done
}

copy_apk() {
    local target_name="$1"

    mkdir -p "$DIST_DIR"
    cp -f "$LAST_BUILT_APK" "$DIST_DIR/$target_name"
    echo "APK lista: $DIST_DIR/$target_name"
}

copy_apks() {
    local prefix="${1:-}"

    mkdir -p "$DIST_DIR"

    for apk in "${LAST_BUILT_APKS[@]}"; do
        local base_name
        base_name="$(basename "$apk")"
        cp -f "$apk" "$DIST_DIR/${prefix}${base_name}"
        echo "APK lista: $DIST_DIR/${prefix}${base_name}"
    done
}

copy_aabs() {
    local prefix="${1:-}"

    mkdir -p "$DIST_DIR"

    for aab in "${LAST_BUILT_AABS[@]}"; do
        local base_name
        base_name="$(basename "$aab")"
        cp -f "$aab" "$DIST_DIR/${prefix}${base_name}"
        echo "AAB listo: $DIST_DIR/${prefix}${base_name}"
    done
}

build_normal() {
    build_variant "normal release" "-final"
    copy_apks
}

build_split() {
    build_normal
}

build_caros() {
    build_variant "debug caros edition" "-debug" -D caros
    copy_apks "caros-"
}

build_aab() {
    build_bundle_variant "release app bundle" "-final" "bundleRelease"
    copy_aabs
}

build_aab_caros() {
    build_bundle_variant "debug caros app bundle" "-debug" "bundleDebug" -D caros
    copy_aabs "caros-"
}

main() {
    local mode="${1:-all}"

    case "$mode" in
        normal|split)
            build_normal
            ;;
        aab|bundle)
            build_aab
            ;;
        aab-caros|bundle-caros)
            build_aab_caros
            ;;
        caros|debug|caros-debug)
            build_caros
            ;;
        all)
            build_normal
            build_caros
            ;;
        *)
            echo "Uso: $0 [all|normal|split|caros|aab|aab-caros]"
            exit 1
            ;;
    esac
}

main "$@"
