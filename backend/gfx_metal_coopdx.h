#ifndef GFX_METAL_COOPDX_H
#define GFX_METAL_COOPDX_H

#include "gfx_rendering_api.h"

extern struct GfxRenderingAPI gfx_metal_coopdx_api;
bool gfx_metal_coopdx_is_ready(void);
bool gfx_metal_coopdx_had_pipeline_error(void);

#endif
