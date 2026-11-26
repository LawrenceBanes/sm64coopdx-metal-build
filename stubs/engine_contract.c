#include "gfx_pc.h"
#include "gfx_sdl.h"
#include "gfx_sdl_metal_layer.h"
#include "pc/configfile.h"

Color gVertexColor = { 255, 255, 255, 255 };
int gShaderFlags[8];
float gShaderFlagValues[8];
unsigned int configFiltering;

void *gfx_sdl_get_metal_layer(void) { return gfx_sdl_metal_layer_get(); }
bool gfx_sdl_uses_metal(void) { return gfx_sdl_metal_layer_is_created(); }
