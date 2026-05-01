#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/app"
DIST_DIR="$ROOT_DIR/dist"
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

build_variant() {
    local label="$1"
    local build_flag="$2"
    local output_name="$3"
    shift 3

    echo "==> Building $label"

    (
        cd "$APP_DIR"
        haxelib run lime clean project.xml android
        haxelib run lime build project.xml android "$build_flag" "$@"
    )

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

main() {
    local mode="${1:-all}"

    require_command haxelib
    require_command unzip
    require_command rg

    case "$mode" in
        normal)
            build_variant "normal build" "-final" "SpritemaptoFunky-normal.apk"
            ;;
        caros|debug|caros-debug)
            build_variant "debug caros edition" "-debug" "SpritemaptoFunky-debug-caros-edition.apk" -D caros
            ;;
        all)
            build_variant "normal build" "-final" "SpritemaptoFunky-normal.apk"
            build_variant "debug caros edition" "-debug" "SpritemaptoFunky-debug-caros-edition.apk" -D caros
            ;;
        *)
            echo "Uso: $0 [all|normal|caros]"
            exit 1
            ;;
    esac
}

main "$@"
