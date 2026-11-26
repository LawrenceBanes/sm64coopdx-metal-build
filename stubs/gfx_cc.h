#ifndef SHADER64_TEST_GFX_CC_H
#define SHADER64_TEST_GFX_CC_H

#include <stdbool.h>
#include <stdint.h>

enum {
    SHADER_0, SHADER_INPUT_1, SHADER_INPUT_2, SHADER_INPUT_3, SHADER_INPUT_4,
    SHADER_INPUT_5, SHADER_INPUT_6, SHADER_INPUT_7, SHADER_INPUT_8,
    SHADER_TEXEL0, SHADER_TEXEL0A, SHADER_TEXEL1, SHADER_TEXEL1A,
    SHADER_1, SHADER_COMBINED, SHADER_COMBINEDA, SHADER_NOISE
};

struct CCFeatures {
    bool used_textures[2];
    int num_inputs;
    bool do_noise;
};

struct ColorCombiner {
    struct {
        uint8_t all_values[16];
        uint32_t flags;
        bool use_alpha, use_fog, texture_edge, use_2cycle, light_map, world_geometry;
    } cm;
    uint8_t shader_input_mapping[16];
    uint8_t shader_commands[16];
    /* Harness-only feature controls; not part of the game ABI. */
    bool test_used_textures[2];
    int test_num_inputs;
    bool test_do_noise;
};

void gfx_cc_get_features(struct ColorCombiner *, struct CCFeatures *);

#endif
