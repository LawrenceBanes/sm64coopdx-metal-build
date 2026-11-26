#include "gfx_metal_coopdx_shader.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { FIXTURE_CAPACITY = 32768 };

static void set_color_passthrough(struct ColorCombiner *cc, uint8_t value) {
    cc->shader_commands[0] = value;
    cc->shader_commands[1] = SHADER_0;
    cc->shader_commands[2] = SHADER_1;
    cc->shader_commands[3] = SHADER_0;
    cc->shader_commands[4] = value;
    cc->shader_commands[5] = SHADER_0;
    cc->shader_commands[6] = SHADER_1;
    cc->shader_commands[7] = SHADER_0;
}

static int emit_one(const char *directory, const char *name, struct ColorCombiner *cc) {
    char source[FIXTURE_CAPACITY];
    struct GfxMetalCoopDXShaderInfo info;
    if (!gfx_metal_coopdx_build_shader(cc, source, sizeof(source), &info)) {
        fprintf(stderr, "shader generator rejected fixture %s\n", name);
        return 0;
    }
    char path[1024];
    int n = snprintf(path, sizeof(path), "%s/%s.metal", directory, name);
    if (n < 0 || (size_t)n >= sizeof(path)) return 0;
    FILE *file = fopen(path, "wb");
    if (!file) { perror(path); return 0; }
    size_t length = strlen(source);
    int ok = fwrite(source, 1, length, file) == length;
    if (fclose(file) != 0) ok = 0;
    if (!ok) { fprintf(stderr, "failed writing fixture %s\n", path); return 0; }
    printf("%s: textures=%d%d inputs=%d alpha=%d fog=%d lightmap=%d stride=%u\n",
           name, info.features.used_textures[0], info.features.used_textures[1],
           info.features.num_inputs, info.alpha, info.fog, info.light_map,
           info.vertex_stride);
    return 1;
}

static void init_combiner(struct ColorCombiner *cc) {
    memset(cc, 0, sizeof(*cc));
    set_color_passthrough(cc, SHADER_1);
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s OUTPUT_DIRECTORY\n", argv[0]);
        return 2;
    }
    struct ColorCombiner cc;
    int ok = 1;

    init_combiner(&cc);
    ok &= emit_one(argv[1], "textureless", &cc);

    init_combiner(&cc);
    cc.test_used_textures[0] = true;
    cc.cm.use_alpha = true;
    cc.cm.texture_edge = true;
    set_color_passthrough(&cc, SHADER_TEXEL0);
    ok &= emit_one(argv[1], "alpha_texture_edge", &cc);

    init_combiner(&cc);
    cc.test_used_textures[1] = true;
    cc.cm.use_alpha = true;
    set_color_passthrough(&cc, SHADER_TEXEL1);
    ok &= emit_one(argv[1], "texture_tile1", &cc);

    init_combiner(&cc);
    cc.test_used_textures[0] = true;
    cc.test_used_textures[1] = true;
    cc.cm.use_alpha = true;
    cc.cm.use_2cycle = true;
    cc.cm.use_fog = true;
    cc.cm.light_map = true;
    cc.cm.world_geometry = true;
    cc.cm.flags = 0x7f;
    cc.test_do_noise = true;
    cc.shader_commands[0] = SHADER_TEXEL0;
    cc.shader_commands[1] = SHADER_0;
    cc.shader_commands[2] = SHADER_1;
    cc.shader_commands[3] = SHADER_0;
    cc.shader_commands[4] = SHADER_TEXEL0;
    cc.shader_commands[5] = SHADER_0;
    cc.shader_commands[6] = SHADER_1;
    cc.shader_commands[7] = SHADER_0;
    cc.shader_commands[8] = SHADER_COMBINED;
    cc.shader_commands[9] = SHADER_0;
    cc.shader_commands[10] = SHADER_1;
    cc.shader_commands[11] = SHADER_0;
    cc.shader_commands[12] = SHADER_COMBINED;
    cc.shader_commands[13] = SHADER_0;
    cc.shader_commands[14] = SHADER_1;
    cc.shader_commands[15] = SHADER_0;
    ok &= emit_one(argv[1], "two_cycle_fog_lightmap", &cc);

    init_combiner(&cc);
    cc.test_used_textures[0] = true;
    cc.test_used_textures[1] = true;
    cc.cm.use_alpha = true;
    cc.cm.world_geometry = true;
    set_color_passthrough(&cc, SHADER_TEXEL0);
    ok &= emit_one(argv[1], "dynos_custom_material_three_point", &cc);

    init_combiner(&cc);
    cc.test_used_textures[0] = true;
    cc.cm.use_alpha = true;
    set_color_passthrough(&cc, SHADER_TEXEL0);
    ok &= emit_one(argv[1], "character_texture_replacement", &cc);

    init_combiner(&cc);
    cc.test_num_inputs = 1;
    cc.cm.use_alpha = true;
    set_color_passthrough(&cc, SHADER_INPUT_1);
    ok &= emit_one(argv[1], "hud_vertex_color_alpha", &cc);

    init_combiner(&cc);
    cc.test_used_textures[0] = true;
    set_color_passthrough(&cc, SHADER_TEXEL0);
    ok &= emit_one(argv[1], "runtime_texture_rebind", &cc);

    return ok ? 0 : 1;
}
