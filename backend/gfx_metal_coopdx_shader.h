#ifndef GFX_METAL_COOPDX_SHADER_H
#define GFX_METAL_COOPDX_SHADER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "gfx_cc.h"

#define GFX_METAL_COOPDX_KEY_SIZE 52

struct GfxMetalCoopDXShaderKey {
    uint8_t bytes[GFX_METAL_COOPDX_KEY_SIZE];
};

struct GfxMetalCoopDXShaderInfo {
    struct CCFeatures features;
    bool alpha;
    bool fog;
    bool texture_edge;
    bool two_cycle;
    bool light_map;
    bool world_geometry;
    uint8_t attribute_count;
    uint16_t vertex_stride;
};

bool gfx_metal_coopdx_shader_key(const struct ColorCombiner *combiner,
                                 struct GfxMetalCoopDXShaderKey *key);
bool gfx_metal_coopdx_shader_key_equal(const struct GfxMetalCoopDXShaderKey *a,
                                       const struct GfxMetalCoopDXShaderKey *b);
bool gfx_metal_coopdx_build_shader(const struct ColorCombiner *combiner,
                                   char *source, size_t source_size,
                                   struct GfxMetalCoopDXShaderInfo *info);

#endif
