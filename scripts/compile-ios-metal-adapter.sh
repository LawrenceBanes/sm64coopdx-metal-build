#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${1:-$ROOT/build/ios-arm64-adapter}"
SDL_SOURCE_DIR="${SDL2_SOURCE_DIR:?set SDL2_SOURCE_DIR to the pinned SDL2 source tree}"
SDL_INCLUDE="$SDL_SOURCE_DIR/include"
SDL_LIBRARY="${SDL2_LIBRARY:?set SDL2_LIBRARY to the pinned iPhoneOS SDL2 static archive}"
SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
mkdir -p "$BUILD_DIR"
ln -sfn "$SDL_INCLUDE" "$BUILD_DIR/SDL2"

COMMON=(--target=arm64-apple-ios15.0 -miphoneos-version-min=15.0 -isysroot "$SDKROOT"
        -I"$BUILD_DIR" -I"$SDL_INCLUDE" -I"$ROOT/stubs" -I"$ROOT/backend")
xcrun --sdk iphoneos clang "${COMMON[@]}" -std=c11 -c \
    "$ROOT/backend/gfx_metal_coopdx_shader.c" \
    -o "$BUILD_DIR/gfx_metal_coopdx_shader.o"
xcrun --sdk iphoneos clang "${COMMON[@]}" -std=c11 -c \
    "$ROOT/stubs/engine_contract.c" \
    -o "$BUILD_DIR/engine_contract.o"
xcrun --sdk iphoneos clang "${COMMON[@]}" -std=c11 -c \
    "$ROOT/stubs/shader_contract.c" \
    -o "$BUILD_DIR/shader_contract.o"
xcrun --sdk iphoneos clang "${COMMON[@]}" -std=c11 -c \
    "$ROOT/backend/gfx_sdl_metal_layer.c" \
    -o "$BUILD_DIR/gfx_sdl_metal_layer.o"
xcrun --sdk iphoneos clang "${COMMON[@]}" -fobjc-arc -fblocks -c \
    "$ROOT/backend/gfx_metal_coopdx.m" \
    -o "$BUILD_DIR/gfx_metal_coopdx.o"
xcrun --sdk iphoneos clang++ --target=arm64-apple-ios15.0 -isysroot "$SDKROOT" \
    -miphoneos-version-min=15.0 -dynamiclib \
    "$BUILD_DIR/gfx_metal_coopdx_shader.o" \
    "$BUILD_DIR/engine_contract.o" \
    "$BUILD_DIR/shader_contract.o" \
    "$BUILD_DIR/gfx_sdl_metal_layer.o" \
    "$BUILD_DIR/gfx_metal_coopdx.o" \
    "$SDL_LIBRARY" \
    -framework Foundation -framework Metal -framework QuartzCore \
    -framework UIKit -framework CoreGraphics \
    -Wl,-undefined,error -Wl,-install_name,@rpath/CoopDXMetalHarness.dylib \
    -o "$BUILD_DIR/CoopDXMetalHarness.dylib"

file "$BUILD_DIR"/*.o "$BUILD_DIR/CoopDXMetalHarness.dylib"
lipo -verify_arch arm64 "$BUILD_DIR/CoopDXMetalHarness.dylib"
xcrun otool -hv -l "$BUILD_DIR/CoopDXMetalHarness.dylib"
xcrun otool -L "$BUILD_DIR/CoopDXMetalHarness.dylib"
xcrun nm -arch arm64 -gU "$BUILD_DIR/CoopDXMetalHarness.dylib" | grep '_gfx_metal_coopdx_api'
xcrun nm -arch arm64 -u "$BUILD_DIR/gfx_sdl_metal_layer.o" | grep '_SDL_Metal_CreateView'
xcrun nm -arch arm64 -u "$BUILD_DIR/CoopDXMetalHarness.dylib" \
    | if grep -E 'gfx_|configFiltering|gVertexColor|gShader'; then
        echo 'unresolved engine contract symbol in linked backend' >&2
        exit 1
      else cat; fi
