#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CC="${CC:-cc}"
FLAGS=(-std=c11 -Wall -Wextra -Werror -I"$ROOT/backend")
if [[ "${SANITIZE:-0}" == "1" ]]; then
    FLAGS+=(-fsanitize=address,undefined -fno-omit-frame-pointer -g)
fi
binary="$(mktemp "${TMPDIR:-/tmp}/touch-math-test.XXXXXX")"
trap 'rm -f "$binary"' EXIT
"$CC" "${FLAGS[@]}" "$ROOT/backend/touchscreen_controls_math.c" \
    "$ROOT/tests/touchscreen_controls_math_test.c" -o "$binary"
"$binary"
echo "Touchscreen hit-priority and axis tests: passed"
