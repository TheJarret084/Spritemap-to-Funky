#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

BIN="build/Spritemap_to_Funky"
if [[ ! -f "$BIN" ]]; then
  echo "Binary not found: $BIN"
  echo "Run ./build_Unix.sh first."
  exit 1
fi

OUT_DIR="dist/Spritemap_to_Funky-linux-x64"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

cp "$BIN" "$OUT_DIR/"
cp -r assets "$OUT_DIR/"
cp README.md LICENSE "$OUT_DIR/"

mkdir -p dist
ARCHIVE="dist/Spritemap_to_Funky-linux-x64.tar.gz"
rm -f "$ARCHIVE"
tar -czf "$ARCHIVE" -C dist Spritemap_to_Funky-linux-x64

echo "Release package created: $ARCHIVE"
