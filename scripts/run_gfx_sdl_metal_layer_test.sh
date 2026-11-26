#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(mktemp /tmp/gfx-sdl-metal-layer-test.XXXXXX)"
trap 'rm -f "$OUT"' EXIT
"${CC:-cc}" -std=c11 -Wall -Wextra -Werror \
    -I"$ROOT/stubs" -I"$ROOT/backend" \
    "$ROOT/tools/gfx_sdl_metal_layer_test.c" \
    "$ROOT/backend/gfx_sdl_metal_layer.c" -o "$OUT"
"$OUT"
