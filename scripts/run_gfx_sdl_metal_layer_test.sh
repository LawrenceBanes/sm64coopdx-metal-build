#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(mktemp /tmp/gfx-sdl-metal-layer-test.XXXXXX)"
trap 'rm -f "$OUT"' EXIT
FLAGS=(-std=c11 -Wall -Wextra -Werror)
if [[ "${SANITIZE:-0}" == 1 ]]; then
    FLAGS+=(-fsanitize=address,undefined -fno-omit-frame-pointer -g)
fi
"${CC:-cc}" "${FLAGS[@]}" \
    -I"$ROOT/stubs" -I"$ROOT/backend" \
    "$ROOT/tools/gfx_sdl_metal_layer_test.c" \
    "$ROOT/backend/gfx_sdl_metal_layer.c" -o "$OUT"
"$OUT"
