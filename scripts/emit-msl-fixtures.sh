#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/build/generated-msl}"
mkdir -p "$OUT"
TMP="$(mktemp "${TMPDIR:-/tmp}/metal-fixture-generator.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

"${CC:-cc}" -std=c11 -Wall -Wextra -Werror \
    -I"$ROOT/stubs" -I"$ROOT/backend" \
    "$ROOT/tools/emit_msl_fixtures.c" \
    "$ROOT/backend/gfx_metal_coopdx_shader.c" \
    "$ROOT/stubs/shader_contract.c" -o "$TMP"
"$TMP" "$OUT"
python3 "$ROOT/tools/check_msl_fixtures.py" "$OUT"
