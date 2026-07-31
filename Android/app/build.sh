#!/usr/bin/env bash

set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$APP_DIR/dist"
APK_OUTPUT_DIR="$APP_DIR/bin/android/bin/app/build/outputs/apk"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Falta comando requerido: $1"
        exit 1
    fi
}

latest_apk() {
    find "$APK_OUTPUT_DIR" -type f -name '*.apk' -printf '%T@ %p\n' 2>/dev/null \
        | sort -n \
        | tail -n 1 \
        | cut -d' ' -f2-
}

verify_apk_abis() {
    local apk="$1"
    local entries
    local missing=0

    entries="$(unzip -Z1 "$apk")"

    for abi in armeabi-v7a arm64-v8a; do
        for lib in liblime.so libApplicationMain.so; do
            if ! rg -q "^lib/$abi/$lib$" <<<"$entries"; then
                echo "Falta lib/$abi/$lib en $apk"
                missing=1
            fi
        done
    done

    if [ "$missing" -ne 0 ]; then
        echo "APK invalida: faltan librerias nativas requeridas."
        exit 1
    fi
}

build_android() {
    local label="$1"
    local build_flag="$2"
    local output_name="$3"
    shift 3

    echo "==> Building Android: $label"
    haxelib run lime clean project.xml android
    haxelib run lime build project.xml android "$build_flag" "$@"

    local apk
    apk="$(latest_apk)"

    if [ -z "$apk" ] || [ ! -f "$apk" ]; then
        echo "No pude localizar la APK generada en $APK_OUTPUT_DIR"
        exit 1
    fi

    verify_apk_abis "$apk"

    mkdir -p "$DIST_DIR"
    cp -f "$apk" "$DIST_DIR/$output_name"
    echo "APK lista: $DIST_DIR/$output_name"
}

build_linux() {
    echo "==> Building Linux desktop"
    haxelib run lime clean project.xml linux
    haxelib run lime build project.xml linux -debug
    echo "Linux listo en: $APP_DIR/bin/linux/bin"
}

test_linux() {
    echo "==> Running Linux desktop"
    haxelib run lime test project.xml linux -debug
}

main() {
    local mode="${1:-all}"

    require_command haxelib
    require_command unzip
    require_command rg

    cd "$APP_DIR"

    case "$mode" in
        android|normal)
            build_android "normal build" "-final" "SpritemaptoFunky-normal.apk"
            ;;
        linux)
            build_linux
            ;;
        test-linux)
            test_linux
            ;;
        caros|debug|caros-debug)
            build_android "debug caros edition" "-debug" "SpritemaptoFunky-debug-caros-edition.apk" -D caros
            ;;
        all)
            build_linux
            build_android "normal build" "-final" "SpritemaptoFunky-normal.apk"
            ;;
        *)
            echo "Uso: $0 [all|android|normal|linux|test-linux|caros]"
            exit 1
            ;;
    esac
}

main "$@"
