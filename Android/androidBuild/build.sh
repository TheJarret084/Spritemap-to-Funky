#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/app"
DIST_DIR="$ROOT_DIR/dist"
ANDROID_APP_DIR="$APP_DIR/bin/android/bin/app"
APK_OUTPUT_DIR="$ANDROID_APP_DIR/build/outputs/apk"
LAST_BUILT_APK=""

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
        haxelib run lime build project.xml android "$build_flag" "${extra_args[@]}"
    )
    after_list="$(find "$APK_OUTPUT_DIR" -type f -name '*.apk' 2>/dev/null | sort || true)"

    LAST_BUILT_APK="$(comm -13 <(printf '%s\n' "$before_list") <(printf '%s\n' "$after_list") | tail -n 1)"
    if [ -z "$LAST_BUILT_APK" ]; then
        LAST_BUILT_APK="$(find "$APK_OUTPUT_DIR" -type f -name '*.apk' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)"
    fi

    if [ -z "$LAST_BUILT_APK" ] || [ ! -f "$LAST_BUILT_APK" ]; then
        echo "No pude localizar la APK generada dentro de $APK_OUTPUT_DIR"
        exit 1
    fi

    echo "APK detectada: $LAST_BUILT_APK"
}

copy_apk() {
    local target_name="$1"

    mkdir -p "$DIST_DIR"
    cp -f "$LAST_BUILT_APK" "$DIST_DIR/$target_name"
    echo "APK lista: $DIST_DIR/$target_name"
}

build_normal() {
    build_variant "normal release" "-final"
    copy_apk "SpritemaptoFunky-normal.apk"
}

build_caros() {
    build_variant "debug caros edition" "-debug" -D caros
    copy_apk "SpritemaptoFunky-debug-caros-edition.apk"
}

main() {
    local mode="${1:-all}"

    case "$mode" in
        normal)
            build_normal
            ;;
        caros|debug|caros-debug)
            build_caros
            ;;
        all)
            build_normal
            build_caros
            ;;
        *)
            echo "Uso: $0 [all|normal|caros]"
            exit 1
            ;;
    esac
}

main "$@"
