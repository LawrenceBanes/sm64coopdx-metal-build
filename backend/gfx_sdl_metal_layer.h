#ifndef GFX_SDL_METAL_LAYER_H
#define GFX_SDL_METAL_LAYER_H

#include <stdbool.h>
#include <SDL2/SDL.h>

bool gfx_sdl_metal_layer_create(SDL_Window *window);
void gfx_sdl_metal_layer_destroy(void);
bool gfx_sdl_metal_layer_is_created(void);
void gfx_sdl_metal_layer_get_drawable_size(SDL_Window *window, int *width, int *height);
void *gfx_sdl_metal_layer_get(void);

#endif
