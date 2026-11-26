#ifndef SDL_metal_h_
#define SDL_metal_h_
#include <SDL2/SDL.h>
typedef void *SDL_MetalView;
SDL_MetalView SDL_Metal_CreateView(SDL_Window *window);
void SDL_Metal_DestroyView(SDL_MetalView view);
void *SDL_Metal_GetLayer(SDL_MetalView view);
void SDL_Metal_GetDrawableSize(SDL_Window *window, int *width, int *height);
#endif
