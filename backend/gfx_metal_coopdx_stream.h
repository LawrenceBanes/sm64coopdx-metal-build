#ifndef GFX_METAL_COOPDX_STREAM_H
#define GFX_METAL_COOPDX_STREAM_H

#include <stdbool.h>
#include <stddef.h>

/* Tracks immutable vertex slices referenced by draw calls in one command buffer. */
struct GfxMetalCoopDXVertexStream {
    size_t used;
    size_t required;
};

static inline void gfx_metal_coopdx_vertex_stream_reset(struct GfxMetalCoopDXVertexStream *stream) {
    if (stream) {
        stream->used = 0;
        stream->required = 0;
    }
}

static inline bool gfx_metal_coopdx_vertex_stream_reserve(
    struct GfxMetalCoopDXVertexStream *stream, size_t bytes, size_t alignment,
    size_t capacity, size_t limit, size_t *offset) {
    if (!stream || !offset || bytes == 0 || alignment == 0 || limit == 0) return false;
    size_t remainder = stream->used % alignment;
    size_t padding = remainder ? alignment - remainder : 0;
    if (stream->used > limit || padding > limit - stream->used) {
        stream->used = limit;
        return false;
    }
    size_t start = stream->used + padding;
    if (bytes > limit - start) {
        stream->used = limit;
        return false;
    }
    size_t end = start + bytes;
    stream->used = end;
    if (end > stream->required) stream->required = end;
    if (end > capacity) return false;
    *offset = start;
    return true;
}

#endif
