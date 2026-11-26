#include <assert.h>
#include <stdbool.h>
#include <stdio.h>

#include <SDL2/SDL_metal.h>
#include "gfx_sdl_metal_layer.h"

struct SDL_Window { int identity; };
static int sCreateCount, sDestroyCount, sSizeCount;
static int sFakeView, sFakeLayer;

SDL_MetalView SDL_Metal_CreateView(SDL_Window *window) {
    assert(window != NULL);
    ++sCreateCount;
    return &sFakeView;
}
void SDL_Metal_DestroyView(SDL_MetalView view) {
    assert(view == &sFakeView);
    ++sDestroyCount;
}
void *SDL_Metal_GetLayer(SDL_MetalView view) {
    assert(view == &sFakeView);
    return &sFakeLayer;
}
void SDL_Metal_GetDrawableSize(SDL_Window *window, int *width, int *height) {
    assert(window != NULL);
    ++sSizeCount;
    if (width) *width = 1170;
    if (height) *height = 2532;
}

int main(void) {
    SDL_Window window = { 1 };
    int width = 0, height = 0;

    assert(!gfx_sdl_metal_layer_is_created());
    assert(gfx_sdl_metal_layer_get() == NULL);
    assert(!gfx_sdl_metal_layer_create(NULL));
    assert(sCreateCount == 0);
    assert(gfx_sdl_metal_layer_create(&window));
    assert(gfx_sdl_metal_layer_create(&window));
    assert(sCreateCount == 1);
    assert(gfx_sdl_metal_layer_is_created());
    assert(gfx_sdl_metal_layer_get() == &sFakeLayer);
    gfx_sdl_metal_layer_get_drawable_size(&window, &width, &height);
    assert(width == 1170 && height == 2532 && sSizeCount == 1);
    gfx_sdl_metal_layer_destroy();
    gfx_sdl_metal_layer_destroy();
    assert(sDestroyCount == 1);
    assert(!gfx_sdl_metal_layer_is_created());
    assert(gfx_sdl_metal_layer_get() == NULL);
    puts("SDL Metal layer lifecycle tests: passed");
    return 0;
}
