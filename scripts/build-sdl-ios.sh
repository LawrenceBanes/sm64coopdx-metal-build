#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${1:-${RUNNER_TEMP:-/tmp}/sm64coopdx-sdl-ios}"
SDL_VERSION=2.32.10
SDL_SHA256=5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165
ARCHIVE="$BUILD_ROOT/SDL2-$SDL_VERSION.tar.gz"
SOURCE="$BUILD_ROOT/SDL2-$SDL_VERSION"
BUILD="$BUILD_ROOT/build"

mkdir -p "$BUILD_ROOT"
mkdir -p "$ROOT/build"
curl --fail --location --retry 3 --output "$ARCHIVE" \
    "https://github.com/libsdl-org/SDL/releases/download/release-$SDL_VERSION/SDL2-$SDL_VERSION.tar.gz"
echo "$SDL_SHA256  $ARCHIVE" | shasum -a 256 -c -
tar -xzf "$ARCHIVE" -C "$BUILD_ROOT"
test -f "$SOURCE/LICENSE.txt"

cmake -S "$SOURCE" -B "$BUILD" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DSDL_SHARED=OFF -DSDL_STATIC=ON \
    -DSDL_TEST=OFF -DSDL_TESTS=OFF \
    -DSDL_METAL=ON -DSDL_VIDEO=ON -DSDL_OPENGL=ON -DSDL_OPENGLES=ON
cmake --build "$BUILD" --config Release --parallel
LIBRARY="$BUILD/libSDL2.a"
test -f "$LIBRARY"
file "$LIBRARY"
xcrun lipo -verify_arch arm64 "$LIBRARY"
xcrun nm -g "$LIBRARY" > "$BUILD_ROOT/sdl-symbols.txt"
grep 'SDL_Metal_CreateView' "$BUILD_ROOT/sdl-symbols.txt"
grep 'SDL_Metal_GetLayer' "$BUILD_ROOT/sdl-symbols.txt"
mkdir -p "$ROOT/build"
cp "$LIBRARY" "$ROOT/build/libSDL2-ios-arm64.a"
cp "$SOURCE/LICENSE.txt" "$ROOT/build/SDL2-LICENSE.txt"
shasum -a 256 "$ROOT/build/libSDL2-ios-arm64.a" "$ROOT/build/SDL2-LICENSE.txt"
