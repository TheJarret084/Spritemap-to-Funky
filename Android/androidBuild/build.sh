#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/app"
DIST_DIR="$ROOT_DIR/dist"
ANDROID_APP_DIR="$APP_DIR/bin/android/bin/app"
APK_OUTPUT_DIR="$ANDROID_APP_DIR/build/outputs/apk"
LAST_BUILT_APK=""
LAST_BUILT_APKS=()

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

build_normal() {
    build_variant "normal release" "-final"
    copy_apks
}

build_caros() {
    build_variant "debug caros edition" "-debug" -D caros
    copy_apks "caros-"
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
