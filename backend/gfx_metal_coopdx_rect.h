#ifndef GFX_METAL_COOPDX_RECT_H
#define GFX_METAL_COOPDX_RECT_H

#include <stdbool.h>
#include <stdint.h>

struct GfxMetalCoopDXScissorRect {
    uint32_t x;
    uint32_t y;
    uint32_t width;
    uint32_t height;
};

/* Clip top-left-origin renderer coordinates, then convert to Metal's bottom-left origin. */
static inline bool gfx_metal_coopdx_clip_scissor(
    int x, int y, int width, int height, uint32_t target_width,
    uint32_t target_height, struct GfxMetalCoopDXScissorRect *result) {
    if (!result || width <= 0 || height <= 0 || target_width == 0 || target_height == 0) return false;
    int64_t x0 = x, y0 = y;
    int64_t x1 = x0 + (int64_t)width, y1 = y0 + (int64_t)height;
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > target_width) x1 = target_width;
    if (y1 > target_height) y1 = target_height;
    if (x0 >= x1 || y0 >= y1 || x0 >= target_width || y0 >= target_height) return false;
    result->x = (uint32_t)x0;
    result->y = target_height - (uint32_t)y1;
    result->width = (uint32_t)(x1 - x0);
    result->height = (uint32_t)(y1 - y0);
    return true;
}

#endif
