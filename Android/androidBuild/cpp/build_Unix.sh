#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$ROOT"
mkdir -p build
cd build
cmake ..
make -j"$(nproc)"
