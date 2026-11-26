#ifndef SHADER64_TEST_GFX_RENDERING_API_H
#define SHADER64_TEST_GFX_RENDERING_API_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* Minimal test contract mirroring the callbacks consumed by the authored adapter. */
struct ShaderProgram;
struct ColorCombiner;
struct GfxRenderingAPI {
    bool (*z_is_from_0_to_1)(void);
    void (*unload_shader)(struct ShaderProgram *);
    void (*load_shader)(struct ShaderProgram *);
    struct ShaderProgram *(*create_and_load_new_shader)(struct ColorCombiner *);
    struct ShaderProgram *(*lookup_shader)(struct ColorCombiner *);
    void (*shader_get_info)(struct ShaderProgram *, uint8_t *, bool [2]);
    uint32_t (*new_texture)(void);
    void (*select_texture)(int, uint32_t);
    void (*upload_texture)(const uint8_t *, int, int);
    void (*set_sampler_parameters)(int, bool, uint32_t, uint32_t);
    void (*set_depth_test)(bool);
    void (*set_depth_mask)(bool);
    void (*set_zmode_decal)(bool);
    void (*set_viewport)(int, int, int, int);
    void (*set_scissor)(int, int, int, int);
    void (*set_use_alpha)(bool);
    void (*draw_triangles)(float *, size_t, size_t);
    void (*init)(void);
    void (*on_resize)(void);
    void (*start_frame)(void);
    void (*end_frame)(void);
    void (*finish_render)(void);
    const char *(*get_name)(void);
    void (*shutdown)(void);
};

#endif
