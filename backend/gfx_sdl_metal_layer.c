#include <SDL2/SDL_metal.h>
#include <stddef.h>

#include "gfx_sdl_metal_layer.h"

static SDL_MetalView sMetalView;

bool gfx_sdl_metal_layer_create(SDL_Window *window) {
    if (sMetalView) return true;
    if (!window) return false;
    sMetalView = SDL_Metal_CreateView(window);
    return sMetalView != NULL;
}

void gfx_sdl_metal_layer_destroy(void) {
    if (!sMetalView) return;
    SDL_Metal_DestroyView(sMetalView);
    sMetalView = NULL;
}

bool gfx_sdl_metal_layer_is_created(void) {
    return sMetalView != NULL;
}

void gfx_sdl_metal_layer_get_drawable_size(SDL_Window *window, int *width, int *height) {
    if (sMetalView && window) SDL_Metal_GetDrawableSize(window, width, height);
}

void *gfx_sdl_metal_layer_get(void) {
    return sMetalView ? SDL_Metal_GetLayer(sMetalView) : NULL;
}
